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
        # top line index currently shown
        self._top = 0

    def _window_size(self) -> int:
        # derive a sensible page size from the widget height; fall back to 10
        try:
            h = int(self.size.height)  # type: ignore[attr-defined]
            # reserve a couple of lines for header/footer
            return max(5, h - 3)
        except Exception:
            return 10

    def append(self, text: str) -> None:
        # Accept multi-line input and append all lines
        for ln in text.splitlines():
            self._lines.append(ln)
        # Keep the last 500 lines to avoid unbounded growth
        if len(self._lines) > 500:
            self._lines = self._lines[-500:]
        # auto-scroll to end when appending new content
        self._top = max(0, len(self._lines) - self._window_size())
        self._render_view()

    def clear(self) -> None:
        self._lines = []
        self._top = 0
        self._render_view()

    def _render_view(self) -> None:
        # render visible window
        win = self._window_size()
        start = max(0, min(self._top, max(0, len(self._lines) - 1)))
        end = start + win
        view = self._lines[start:end]
        self.update("\n".join(view))

    # Scrolling API used by the app
    def scroll_lines(self, delta: int) -> None:
        if not self._lines:
            return
        self._top = max(0, min(self._top + delta, max(0, len(self._lines) - self._window_size())))
        self._render_view()

    def page(self, forward: bool = True) -> None:
        n = self._window_size()
        self.scroll_lines(n if forward else -n)

    def go_top(self) -> None:
        self._top = 0
        self._render_view()

    def go_end(self) -> None:
        self._top = max(0, len(self._lines) - self._window_size())
        self._render_view()


class Menu(Static):
    def compose(self) -> ComposeResult:
        yield Button('1) Overview', id='overview')
        yield Button('2) Network', id='network')
        yield Button('3) Services', id='services')
        yield Button('4) Crypto', id='crypto')
        yield Button('5) Peers', id='peers')
        yield Button('6) Deploy', id='deploy')
        yield Button('7) Diagnostics', id='diagnostics')
        yield Button('8) Logs', id='logs')
        yield Button('9) Advanced', id='advanced')
        yield Button('Q) Quit', id='quit')


class ContentPanel(Static):
    """Central panel for rendering main content (tables, status, checklists)."""
    def on_mount(self) -> None:
        self.update('Select a section from the left to begin.')

    def show_text(self, text: str) -> None:
        self.update(text)


class ProNixApp(App):
    CSS_PATH = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=False)
        with Horizontal():
            with Vertical():
                yield Menu()
            with Vertical():
                # left: menu, center: content panel, right: live log
                self.content = ContentPanel()
                yield self.content
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
        # initial render
        try:
            self._render_overview()
        except Exception:
            pass
        # pending confirmation action state
        self._pending_action: dict | None = None

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
        elif btn == 'overview':
            # render the overview content synchronously
            self._render_overview()
            return
        elif btn == 'network':
            self._render_network()
            return
        elif btn == 'services':
            self._render_services()
            return
        elif btn == 'crypto':
            self._render_crypto()
            return
        elif btn == 'peers':
            self._render_peers()
            return
        elif btn == 'deploy':
            self._render_deploy()
            return
        elif btn == 'logs':
            self._render_logs()
            return
        elif btn == 'advanced':
            self._render_advanced()
            return
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
        # also ensure content panel shows the running task
        try:
            self.content.show_text(f'Running: {" ".join(cmd)}\nSee logs on the right for live output.')
        except Exception:
            pass

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
            # also show overview
            self._render_overview()
        elif key == '2':
            asyncio.create_task(self._run_and_show([sys.executable, str(PROCTL), 'diagnostics']))
            # also show checklist
            self._render_checklist()
        elif key == '3':
            asyncio.create_task(self._run_and_show([sys.executable, str(PROCTL), 'exec', 'uname', '-a']))
            self._render_services()
        elif key in ('A',):
            # restart avahi
            self._request_confirm('Restart avahi-daemon (requires sudo)', ['sudo','systemctl','restart','avahi-daemon'])
        elif key in ('S',):
            # restart sshd
            self._request_confirm('Restart sshd (requires sudo)', ['sudo','systemctl','restart','sshd'])
        elif key in ('K',):
            # run key sync
            self._request_confirm('Run pro-peer key sync (sudo)', ['sudo','/etc/pro-peer-sync-keys.sh','--input','/etc/pro-peer/authorized_keys.gpg','--out','/var/lib/pro-peer/authorized_keys'])
        elif key in ('j', 'J', 'down'):
            # single-line scroll down
            self.output.scroll_lines(1)
        elif key in ('k', 'K', 'up'):
            # single-line scroll up
            self.output.scroll_lines(-1)
        elif key in (' ', 'pagedown'):
            self.output.page(forward=True)
        elif key in ('b', 'pageup'):
            self.output.page(forward=False)
        elif key == 'g':
            self.output.go_top()
        elif key == 'G':
            self.output.go_end()
        elif key in ('q', 'Q'):
            # try to terminate running process, then exit
            try:
                if getattr(self, '_running_proc', None):
                    self._running_proc.terminate()
                    self.output.append('Sent SIGTERM to running process...')
            except Exception:
                pass
            self.exit()
        # confirmation handling
        if key in ('y', 'Y') and self._pending_action:
            # execute pending action
            cmd = self._pending_action.get('cmd')
            desc = self._pending_action.get('desc')
            self._pending_action = None
            if cmd:
                asyncio.create_task(self._run_and_show(cmd))
                try:
                    self.content.show_text(f'Executing: {desc}\nSee logs on the right for output.')
                except Exception:
                    pass
            return
        if key in ('n', 'N') and self._pending_action:
            self._pending_action = None
            try:
                self.content.show_text('Action cancelled')
            except Exception:
                pass
            return

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

    # ------------------------- Render helpers -------------------------
    def _run_cmd(self, cmd: list[str], timeout: int = 5) -> tuple[int, str, str]:
        try:
            p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            return p.returncode, p.stdout.strip(), p.stderr.strip()
        except subprocess.TimeoutExpired:
            return 252, '', 'timeout'
        except FileNotFoundError:
            return 253, '', f'not found: {cmd[0]}'
        except Exception as e:
            return 254, '', str(e)

    def _render_overview(self) -> None:
        import socket, platform, shutil

        lines = []
        lines.append(f'Host: {socket.gethostname()}')
        lines.append(f'OS: {platform.system()} {platform.release()} ({platform.version()})')

        # Loadavg
        try:
            with open('/proc/loadavg', 'r') as f:
                load = f.read().strip().split()[:3]
            lines.append(f'Load (1/5/15): {load[0]} {load[1]} {load[2]}')
        except Exception:
            lines.append('Load: unavailable')

        # Memory
        try:
            mem = {}
            with open('/proc/meminfo') as f:
                for ln in f:
                    k, v = ln.split(':', 1)
                    mem[k.strip()] = v.strip()
            total = int(mem.get('MemTotal','0').split()[0])
            free = int(mem.get('MemAvailable', mem.get('MemFree','0')).split()[0])
            used_pct = (total - free) * 100 // total if total else 0
            lines.append(f'Memory: {used_pct}% used ({(total-free)//1024}MB/{total//1024}MB)')
        except Exception:
            lines.append('Memory: unavailable')

        # Disk
        try:
            du = shutil.disk_usage('/')
            used_pct = du.used * 100 // du.total
            lines.append(f'Disk /: {used_pct}% used ({du.free//1024//1024}MB free)')
        except Exception:
            lines.append('Disk: unavailable')

        # IPs (brief)
        rc, out, err = self._run_cmd(['ip','-4','addr','show'])
        if rc == 0 and out:
            ip_lines = out.splitlines()[:8]
            lines.append('Interfaces (ipv4):')
            lines.extend(ip_lines)
        else:
            lines.append('Interfaces: unavailable')

        # Services quick status
        services = ['sshd','avahi-daemon','pro-peer-sync-keys','tor','yggdrasil','headscale','i2p']
        svc_lines = []
        for s in services:
            rc, out, err = self._run_cmd(['systemctl','is-active', s])
            state = out if rc==0 else 'inactive'
            svc_lines.append(f'{s}: {state}')
        lines.append('Services: ' + ', '.join(svc_lines))

        # show checklist hint
        lines.append('\nChecklist:')
        lines.append(' - Avahi running? (Network -> check)')
        lines.append(' - SSH configured for key auth? (Services -> check)')
        lines.append(' - Encrypted authorized_keys present? (Crypto -> check)')

        try:
            self.content.show_text('\n'.join(lines))
        except Exception:
            pass

    def _render_network(self) -> None:
        lines = []
        lines.append('Network Overview')
        rc, out, err = self._run_cmd(['ip','-brief','addr'])
        if rc == 0 and out:
            lines.extend(out.splitlines())
        else:
            lines.append('ip command unavailable or failed')

        rc, out, err = self._run_cmd(['ip','route','show','default'])
        if rc == 0 and out:
            lines.append('\nDefault route:')
            lines.extend(out.splitlines())

        # DNS servers
        try:
            with open('/etc/resolv.conf') as f:
                dns = [ln.strip() for ln in f if ln.startswith('nameserver')]
            lines.append('\nDNS:')
            lines.extend(dns if dns else ['(none)'])
        except Exception:
            lines.append('\nDNS: unavailable')

        # Avahi status
        rc, out, err = self._run_cmd(['systemctl','is-active','avahi-daemon'])
        lines.append(f'Avahi: {out if rc==0 else "inactive"}')

        try:
            self.content.show_text('\n'.join(lines))
        except Exception:
            pass

    def _render_services(self) -> None:
        lines = []
        lines.append('Services Status')
        services = ['sshd','avahi-daemon','pro-peer-sync-keys','tor','yggdrasil','headscale','i2p']
        for s in services:
            rc, out, err = self._run_cmd(['systemctl','is-active', s])
            enabled_rc, enabled_out, _ = self._run_cmd(['systemctl','is-enabled', s])
            state = out if rc==0 else 'inactive'
            enabled = enabled_out if enabled_rc==0 else 'disabled'
            lines.append(f'{s:20} {state:10} {enabled:10}')

        try:
            self.content.show_text('\n'.join(lines))
        except Exception:
            pass

    def _render_crypto(self) -> None:
        self.content.show_text('Crypto: select encrypted authorized_keys.gpg in Crypto screen (coming soon)')

    def _render_peers(self) -> None:
        self.content.show_text('Peers: discovery will list mDNS peers (coming soon)')

    def _render_deploy(self) -> None:
        self.content.show_text('Deploy: run pro-peer-master flow (coming soon)')

    def _render_logs(self) -> None:
        # list recent logs
        base = os.path.expanduser('~/.local/share/pro-nix/ui-logs')
        try:
            files = sorted([os.path.join(base,f) for f in os.listdir(base)], key=os.path.getmtime, reverse=True)
            if not files:
                self.content.show_text('No saved logs')
                return
            head = files[:5]
            lines = ['Recent logs:']
            for p in head:
                lines.append(p)
            self.content.show_text('\n'.join(lines))
        except Exception:
            self.content.show_text('No logs directory or inaccessible')

    def _render_advanced(self) -> None:
        self.content.show_text('Advanced: headscale/tor/yggdrasil/i2p helpers (coming soon)')

    # ------------------------- Checklist helpers -------------------------
    def _render_checklist(self) -> None:
        """Render checklist with actionable hints into the content panel."""
        items = []
        # Avahi
        rc, out, err = self._run_cmd(['systemctl','is-active','avahi-daemon'])
        avahi_state = 'OK' if rc==0 and out=='active' else 'MISSING'
        items.append(f'Avahi (mDNS): {avahi_state}  [A=restart]')
        # SSH
        rc, out, err = self._run_cmd(['systemctl','is-active','sshd'])
        ssh_state = 'OK' if rc==0 and out=='active' else 'MISSING'
        items.append(f'SSHD: {ssh_state}  [S=restart]')
        # authorized_keys.gpg
        path = '/etc/pro-peer/authorized_keys.gpg'
        if os.path.exists(path):
            items.append(f'Encrypted authorized_keys: present ({path})  [K=sync keys]')
        else:
            items.append(f'Encrypted authorized_keys: MISSING ({path})')
        # pro-peer sync service
        rc, out, err = self._run_cmd(['systemctl','is-active','pro-peer-sync-keys'])
        pp_state = 'OK' if rc==0 and out=='active' else 'inactive'
        items.append(f'pro-peer-sync-keys: {pp_state}  [K=run sync]')

        lines = ['Checklist:'] + ['  ' + it for it in items] + ['', 'Confirm actions: press uppercase key to request confirmation, then Y to proceed.']
        try:
            self.content.show_text('\n'.join(lines))
        except Exception:
            pass

    def _request_confirm(self, desc: str, cmd: list[str]) -> None:
        self._pending_action = {'desc': desc, 'cmd': cmd}
        try:
            self.content.show_text(f'Confirm: {desc}\nPress Y to proceed or N to cancel')
        except Exception:
            pass


def main() -> None:
    ProNixApp().run()


if __name__ == '__main__':
    main()
