#!/usr/bin/env python3
"""Simple Textual-based prototype TUI for pro-nix management.

This is a minimal prototype using textual to show a menu and call proctl.
"""
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button, TextLog
from textual.containers import Horizontal, Vertical
import subprocess
import sys
from pathlib import Path


PROCTL = Path('tui/proctl.py')


class Menu(Static):
    def compose(self) -> ComposeResult:
        yield Button('List interfaces', id='list-ifaces')
        yield Button('Diagnostics', id='diagnostics')
        yield Button('Run cmd', id='run-cmd')


class OutputPanel(Static):
    def compose(self) -> ComposeResult:
        yield TextLog(highlight=True, wrap=True, id='out')


class ProNixApp(App):
    CSS_PATH = None

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            yield Menu()
            yield OutputPanel()
        yield Footer()

    async def on_button_pressed(self, event):
        id = event.button.id
        out = self.query_one('#out', TextLog)
        out.clear()
        if id == 'list-ifaces':
            p = subprocess.Popen([sys.executable, str(PROCTL), 'list-ifaces'], stdout=subprocess.PIPE)
            for line in p.stdout:
                out.write(line.decode('utf-8', errors='replace').rstrip())
        elif id == 'diagnostics':
            p = subprocess.Popen([sys.executable, str(PROCTL), 'diagnostics'], stdout=subprocess.PIPE)
            for line in p.stdout:
                out.write(line.decode('utf-8', errors='replace').rstrip())
        elif id == 'run-cmd':
            # small example: show uname -a
            p = subprocess.Popen([sys.executable, str(PROCTL), 'exec', 'uname', '-a'], stdout=subprocess.PIPE)
            for line in p.stdout:
                out.write(line.decode('utf-8', errors='replace').rstrip())


def main():
    app = ProNixApp()
    app.run()


if __name__ == '__main__':
    main()
