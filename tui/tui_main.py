#!/usr/bin/env python3
"""Simple Textual-based TUI prototype for pro-nix management.

This prototype demonstrates a menu with Diagnostics and Interfaces actions and
wires them to the small proctl wrapper. The goal is to keep code minimal.
"""
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Button, Static, TextLog
from textual.containers import Horizontal, Vertical
import subprocess
import sys
from pathlib import Path

PROCTL = Path(__file__).resolve().parent / 'proctl.py'


class Menu(Static):
    def compose(self) -> ComposeResult:
        yield Button('Diagnostics', id='diag')
        yield Button('List Interfaces', id='ifaces')
        yield Button('Quit', id='quit')


class Output(TextLog):
    def append_cmd(self, cmd):
        self.write(f'$ {cmd}')
        try:
            p = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
            if p.stdout:
                self.write(p.stdout)
            if p.stderr:
                self.write('ERR: ' + p.stderr)
        except Exception as e:
            self.write('exception: ' + str(e))


class ProNixApp(App):
    CSS_PATH = None

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical():
                yield Menu()
            with Vertical():
                self.out = Output(highlight=True)
                yield self.out
        yield Footer()

    def on_button_pressed(self, event):
        id = event.button.id
        if id == 'diag':
            self.out.append_cmd(f'python3 "{PROCTL}" diagnostics')
        elif id == 'ifaces':
            self.out.append_cmd(f'python3 "{PROCTL}" list-ifaces')
        elif id == 'quit':
            self.exit()


def main():
    app = ProNixApp()
    app.run()


if __name__ == '__main__':
    main()
