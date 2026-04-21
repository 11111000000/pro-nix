#!/usr/bin/env python3
"""Minimal TUI prototype using textual (fast to prototype)

Provides:
- menu with: Overview, Network, Keys, Diagnostics, Quit
- ability to call proctl CLI (scripts/proctl) for list-ifaces and check-join-secret
"""
import asyncio
import json
import os
from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button, Input, TextLog, RadioSet, RadioButton
from textual.containers import Horizontal, Vertical
from textual.reactive import reactive
from textual.events import Key


PROCTL = os.path.join(os.path.dirname(__file__), '..', 'proctl', 'cli.py')


class Menu(Static):
    def compose(self) -> ComposeResult:
        yield Button("Overview", id="overview")
        yield Button("Network", id="network")
        yield Button("Keys", id="keys")
        yield Button("Diagnostics", id="diag")
        yield Button("Quit", id="quit")


class MainApp(App):
    CSS_PATH = None
    BINDINGS = [("q", "quit", "Quit")]

    secret_valid = reactive(False)

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            yield Menu()
            with Vertical():
                yield Static("Pro-Nix TUI", id="title")
                yield TextLog(highlight=True, id="log")
        yield Footer()

    async def on_mount(self):
        self.log = self.query_one("#log", TextLog)
        await self.show_overview()

    async def show_overview(self):
        self.log.clear()
        self.log.write("Overview:\n")
        # list ifaces
        proc = await asyncio.create_subprocess_exec("python3", PROCTL, "list-ifaces", stdout=asyncio.subprocess.PIPE)
        out, _ = await proc.communicate()
        try:
            j = json.loads(out.decode())
            self.log.write(f"Interfaces: {j.get('ifaces')}")
        except Exception:
            self.log.write(out.decode())

    async def action_quit(self):
        await self.shutdown()

    async def on_button_pressed(self, event):
        btn = event.button.id
        if btn == 'overview':
            await self.show_overview()
        elif btn == 'network':
            await self.show_network()
        elif btn == 'keys':
            await self.show_keys()
        elif btn == 'diag':
            await self.run_diag()
        elif btn == 'quit':
            await self.action_quit()

    async def show_network(self):
        self.log.clear()
        self.log.write("Network:\n")
        self.log.write("Commands: check join secret\n")
        # show input
        inp = Input(placeholder="/path/to/secret.gpg", id="secretpath")
        btn = Button("Check secret", id="chksec")
        await self.mount(inp, after="#title")
        await self.mount(btn, after=inp)

    async def show_keys(self):
        self.log.clear()
        self.log.write("Keys panel (prototype)\n")

    async def run_diag(self):
        self.log.clear()
        self.log.write("Running diagnostics (stub)\n")


def main():
    app = MainApp()
    app.run()


if __name__ == '__main__':
    main()
