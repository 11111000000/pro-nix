#!/usr/bin/env python3
"""Textual-based quick prototype for pro-nix TUI.

Dependencies: textual (pip install textual)

This is a minimal prototype demonstrating menu, services page and diagnostics.
"""
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Header, Footer, Static, Button, ListView, ListItem, Label, TextLog
import subprocess
import threading
from pathlib import Path


class MenuItem(ListItem):
    def __init__(self, name: str):
        super().__init__(Label(name))
        self.name = name


class ProNixApp(App):
    CSS = """
ListView {width: 30}
TextLog {background: #111111}
"""

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical():
                self.menu = ListView(*[MenuItem(n) for n in ['Overview','Services','Diagnostics','Samba','Pro-peer','Quit']])
                yield self.menu
            with Vertical():
                self.title = Static("Overview", id="title")
                yield self.title
                self.body = TextLog()
                yield self.body
        yield Footer()

    def on_mount(self) -> None:
        self.query_one(ListView).focus()
        self.menu.index = 0
        self.do_overview()

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        name = event.item.name
        if name == 'Quit':
            self.exit()
        elif name == 'Overview':
            self.do_overview()
        elif name == 'Diagnostics':
            self.do_diagnostics()

    def do_overview(self):
        self.title.update('Overview')
        self.body.clear()
        self.body.write('pro-nix quick overview')
        # show some info
        try:
            out = subprocess.check_output(['uname','-a'], text=True)
            self.body.write(out)
        except Exception as e:
            self.body.write('uname failed: '+str(e))

    def do_diagnostics(self):
        self.title.update('Diagnostics')
        self.body.clear()
        self.body.write('Running diagnostics...')
        def run():
            d = Path(__file__).resolve().parent.parent / 'scripts' / 'run-samba-diagnostics.sh'
            if d.exists():
                p = subprocess.run([str(d)], capture_output=True, text=True)
                self.body.write(p.stdout)
                if p.stderr:
                    self.body.write('ERR:'+p.stderr)
            else:
                self.body.write('diagnostics script not found')
        t = threading.Thread(target=run)
        t.start()


if __name__ == '__main__':
    ProNixApp().run()
