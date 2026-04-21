#!/usr/bin/env python3
"""Minimal TUI prototype using textual-like layout but without heavy deps.

This is a small curses-based TUI that uses python's curses and simple layout
to present a menu and run proctl commands, streaming output to a pane.

It's intentionally minimal and avoids external UI libs to keep dependency
surface small for prototype. Replace with Textual/tview later if desired.
"""
import curses
import json
import subprocess
import shlex
from pathlib import Path
import sys


PROCTL = Path('tui/proctl.py')


def run_proctl(args):
    cmd = f'python3 {shlex.quote(str(PROCTL))} ' + args
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, timeout=60)
        return 0, out.decode('utf-8', errors='replace')
    except subprocess.CalledProcessError as e:
        return e.returncode, e.output.decode('utf-8', errors='replace')
    except subprocess.TimeoutExpired as e:
        return 124, 'timeout'


MENU = ['Overview', 'Interfaces', 'Diagnostics', 'Backups', 'Restore Backup', 'Exec', 'Quit']


def draw_menu(stdscr, selected):
    h, w = stdscr.getmaxyx()
    stdscr.clear()
    stdscr.addstr(0, 2, 'pro-nix TUI', curses.A_BOLD)
    for idx, item in enumerate(MENU):
        attr = curses.A_REVERSE if idx == selected else curses.A_NORMAL
        stdscr.addstr(2 + idx, 2, item.ljust(20), attr)


def draw_output(stdscr, text):
    h, w = stdscr.getmaxyx()
    lines = text.splitlines()
    maxh = h - 2
    start = max(0, len(lines) - maxh)
    for i, line in enumerate(lines[start: start + maxh]):
        stdscr.addstr(2 + i, 24, line[:w-26])


def main(stdscr):
    curses.curs_set(0)
    selected = 0
    output = 'Ready.'
    while True:
        draw_menu(stdscr, selected)
        draw_output(stdscr, output)
        stdscr.refresh()
        ch = stdscr.getch()
        if ch == curses.KEY_DOWN:
            selected = (selected + 1) % len(MENU)
        elif ch == curses.KEY_UP:
            selected = (selected - 1) % len(MENU)
        elif ch in (curses.KEY_ENTER, 10, 13):
            choice = MENU[selected]
            if choice == 'Quit':
                break
            elif choice == 'Overview':
                rc, out = run_proctl('list-ifaces')
                output = out
            elif choice == 'Interfaces':
                rc, out = run_proctl('list-ifaces')
                output = out
            elif choice == 'Diagnostics':
                rc, out = run_proctl('diagnostics')
                output = out
            elif choice == 'Backups':
                rc, out = run_proctl('list-backups')
                output = out
            elif choice == 'Restore Backup':
                # prompt for path
                curses.echo()
                stdscr.addstr(20, 2, 'Backup path: ')
                path = stdscr.getstr(20, 15, 60).decode('utf-8')
                curses.noecho()
                rc, out = run_proctl(f'restore-backup {shlex.quote(path)}')
                output = out
            elif choice == 'Exec':
                curses.echo()
                stdscr.addstr(20, 2, 'Command: ')
                cmd = stdscr.getstr(20, 11, 120).decode('utf-8')
                curses.noecho()
                rc, out = run_proctl(f"exec {shlex.quote(cmd)}")
                output = out
        elif ch in (ord('q'), 27):
            break


if __name__ == '__main__':
    curses.wrapper(main)
