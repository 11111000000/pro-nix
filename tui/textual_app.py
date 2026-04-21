"""Textual prototype TUI for pro-nix management.

This is a small prototype using Textual. It depends on textual package.
It integrates with tui/proctl.py to perform actions.
"""
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button, TextLog, TreeControl, TreeNode
from textual.containers import Horizontal, Vertical
from textual.reactive import reactive
import subprocess
import sys
from pathlib import Path

PROCTL = Path('tui/proctl.py')


def run_proctl(*args):
    cmd = [sys.executable, str(PROCTL)] + list(args)
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    out, _ = p.communicate()
    return p.returncode, out.decode('utf-8', errors='replace')


class MenuTree(Static):
    def compose(self) -> ComposeResult:
        tree = TreeControl("Menu", "root")
        yield tree


class MainApp(App):
    CSS_PATH = None
    BINDINGS = [("q", "quit", "Quit")]

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical():
                self.menu = TreeControl("Menu", "root")
                yield self.menu
            with Vertical():
                yield Static("Output")
                self.log = TextLog()
                yield self.log
        yield Footer()

    def on_mount(self):
        # populate menu
        root = self.menu.root
        for name in ["Overview", "Services", "Pro-peer", "Samba", "Diagnostics", "Fonts", "System"]:
            self.menu.add(root, name, name)
        self.menu.root.expand()
        self.menu.show_root = True
        self.menu.focus()

    async def on_tree_control_node_selected(self, event: TreeControl.NodeSelected) -> None:
        name = event.node.data
        self.log.write(f"Selected {name}")
        if name == 'Diagnostics':
            rc, out = run_proctl('diagnostics')
            self.log.write(out)
        elif name == 'Overview':
            rc, out = run_proctl('list-ifaces')
            self.log.write(out)


def main():
    app = MainApp()
    app.run()


if __name__ == '__main__':
    main()
