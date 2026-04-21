#!/usr/bin/env python3
"""User-friendly TUI for pro-nix prototype.

This is a small, robust UI intended to be obvious and work across Textual
versions. Buttons run commands (in a thread) and their output is shown in a
scrollable text area. The code is deliberately simple so it behaves
predictably inside the Nix-provided environment.
"""
from __future__ import annotations

import asyncio
import subprocess
import sys
import signal
import time
import threading
import os
from pathlib import Path

from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Button, Static
from textual.containers import Horizontal, Vertical


PROCTL = Path(__file__).resolve().parent / 'proctl.py'


class TextArea(Static):
    """Simple text area that accumulates lines and renders them.

    We avoid depending on Textual's TextLog because widget exports change
    between versions. This minimal widget supports append/clear and keeps
    content visible.
    """
    def on_mount(self) -> None:
        self._lines: list[str] = []

    def append(self, text: str) -> None:
        # Accept multi-line input and append all lines
        for ln in text.splitlines():
            self._lines.append(ln)
        # Keep the last 500 lines to avoid unbounded growth
        if len(self._lines) > 500:
            self._lines = self._lines[-500:]
        self.update("\n".join(self._lines))

    def clear(self) -> None:
        self._lines = []
        self.update("")


class Menu(Static):
    def compose(self) -> ComposeResult:
        yield Button('1) List interfaces', id='list-ifaces')
        yield Button('2) Diagnostics', id='diagnostics')
        yield Button('3) Run uname -a', id='run-cmd')
        yield Button('Q) Quit', id='quit')


class ProNixApp(App):
    CSS_PATH = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False)
        with Horizontal():
            with Vertical():
                yield Menu()
            with Vertical():
                self.output = TextArea()
                yield self.output
        yield Footer()

    def on_mount(self) -> None:
        self.output.clear()
        self.output.append('Pro-Nix TUI (prototype)')
        self.output.append('Use the buttons on the left or press 1/2/3 to run actions.')
        self.output.append('Output appears here. Press Q to quit.')
        # track the currently running subprocess (Popen) so we can cancel it
        self._running_proc: subprocess.Popen | None = None
        # ctrl-c handling: require double-press to force quit when nothing is running
        self._last_sigint = 0.0
        self._sigint_count = 0

        # register SIGINT handler to support Ctrl-C inside the TUI (best-effort)
        try:
            loop = asyncio.get_running_loop()
            loop.add_signal_handler(signal.SIGINT, lambda: asyncio.create_task(self._on_sigint()))
        except Exception:
            # some environments (like certain terminals) may not support this
            pass

    async def on_button_pressed(self, event) -> None:
        btn = event.button.id
        if btn == 'quit':
            # try to terminate any running process, then exit immediately
            try:
                if getattr(self, '_running_proc', None):
                    self._running_proc.terminate()
                    self.output.append('Sent SIGTERM to running process...')
            except Exception:
                pass
            self.exit()
            return

        if btn == 'list-ifaces':
            cmd = [sys.executable, str(PROCTL), 'list-ifaces']
        elif btn == 'diagnostics':
            cmd = [sys.executable, str(PROCTL), 'diagnostics']
        elif btn == 'run-cmd':
            cmd = [sys.executable, str(PROCTL), 'exec', 'uname', '-a']
        else:
            self.output.append(f'Unknown action: {btn}')
            return

        await self._run_and_show(cmd)

    async def _run_and_show(self, cmd: list[str]) -> None:
        """Run command in a background thread and stream output to UI.

        We use a thread with subprocess.Popen(start_new_session=True) so we can
        reliably terminate the whole process group. Output lines are forwarded
        to the TextArea via the asyncio loop's thread-safe callbacks.
        """
        loop = asyncio.get_running_loop()
        self.output.clear()
        self.output.append(f'>>> Running: {" ".join(cmd)}')

        def target():
            try:
                # start in a new process session so we can kill the group
                p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True)
            except FileNotFoundError:
                loop.call_soon_threadsafe(self.output.append, f'Error: executable not found: {cmd[0]}')
                return
            except Exception as e:
                loop.call_soon_threadsafe(self.output.append, f'Failed to start process: {e}')
                return

            self._running_proc = p

            # read stdout and stderr lines
            def pump(stream, prefix=''):
                try:
                    for raw in stream:
                        line = raw.rstrip('\n')
                        loop.call_soon_threadsafe(self.output.append, f'{prefix}{line}')
                except Exception as e:
                    loop.call_soon_threadsafe(self.output.append, f'ERR: reader failed: {e}')

            t_out = threading.Thread(target=pump, args=(p.stdout, ''), daemon=True)
            t_err = threading.Thread(target=pump, args=(p.stderr, 'ERR: '), daemon=True)
            t_out.start()
            t_err.start()

            rc = p.wait()
            t_out.join()
            t_err.join()
            loop.call_soon_threadsafe(self.output.append, f'--- exited with {rc} ---')
            self._running_proc = None

        thread = threading.Thread(target=target, daemon=True)
        thread.start()
        # return immediately; the background thread will update the UI

    def on_key(self, event) -> None:
        # numeric shortcuts
        key = getattr(event, 'key', None)
        if not key:
            return
        # also handle Ctrl-C pressed as key (Textual may expose it as '\x03' or 'ctrl+c')
        if key in ('\x03', 'ctrl+c'):
            asyncio.create_task(self._on_sigint())
            return
        if key == '1':
            asyncio.create_task(self._run_and_show([sys.executable, str(PROCTL), 'list-ifaces']))
        elif key == '2':
            asyncio.create_task(self._run_and_show([sys.executable, str(PROCTL), 'diagnostics']))
        elif key == '3':
            asyncio.create_task(self._run_and_show([sys.executable, str(PROCTL), 'exec', 'uname', '-a']))
        elif key in ('q', 'Q'):
            # try to terminate running process, then exit
            try:
                if getattr(self, '_running_proc', None):
                    self._running_proc.terminate()
                    self.output.append('Sent SIGTERM to running process...')
            except Exception:
                pass
            self.exit()

    async def _on_sigint(self) -> None:
        """Handle SIGINT (Ctrl-C). If a process is running, terminate it.

        If no process runs, require double Ctrl-C to quit (to avoid accidental
        exits)."""
        now = time.time()
        if getattr(self, '_running_proc', None):
            try:
                self._running_proc.terminate()
                self.output.append('Ctrl-C: terminating running process...')
            except Exception as e:
                self.output.append(f'Ctrl-C: failed to terminate process: {e}')
            return

        # no running proc: require double press within 1.5s
        if now - self._last_sigint < 1.5:
            self.output.append('Ctrl-C pressed twice: exiting')
            self.exit()
            return
        self._last_sigint = now
        self.output.append('Press Ctrl-C again quickly to quit')


def main() -> None:
    ProNixApp().run()


if __name__ == '__main__':
    main()
