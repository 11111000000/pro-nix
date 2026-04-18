# Emacs headless tests

## Goal

Give agents a reproducible way to load the Emacs config in two modes:

- TTY
- Xorg / GUI under Xvfb

Each run must collect logs so the next change can be judged by evidence, not guesswork.

## Entry point

Use:

```bash
pro-emacs-headless-test both
```

Or one mode at a time:

```bash
pro-emacs-headless-test tty
pro-emacs-headless-test xorg
```

## Log layout

Default log directory:

```text
./logs/emacs-headless/<timestamp>/
```

Files:

- `run.log` - combined master log
- `tty.log` - TTY run output
- `xorg.log` - Xorg/Xvfb run output

## What the agent should inspect

- whether `~/.emacs.d/init.el` loads cleanly
- whether `site-init.el` finds the expected modules
- whether the TTY run prints errors about unsupported UI features
- whether the Xorg run can create a frame and load the visual layer

## System dependency

The Xorg test needs `Xvfb` available in the system environment.

If the command is missing, add the Xorg server package to the Nix layer and rerun the test.

## Philosophy

This is not a benchmark. It is a witness.

The runner should leave behind enough evidence for an agent to explain what changed, what failed, and what should be fixed next.
