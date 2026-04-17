# pro.old -> pro-nix: priority transfer analysis

## Thesis

`pro.old` contains a useful core idea: Emacs is treated as an operating surface, not just an editor. The strongest parts are the ones that reduce friction at startup and in daily work:

- early bootstrap hygiene
- compact navigation defaults
- Nix editing and rebuild entry points
- a small AI entrypoint
- terminal workflow glue

## Antithesis

The old config also shows a structural weakness: it tends to accumulate policy, UI taste, and domain-specific experiments into large feature files. That creates three problems:

- too much surface area for startup and maintenance
- duplicated behavior across modules
- configuration that reads well as prose but is hard to keep minimal and stable

The biggest anti-pattern is not any single feature. It is the habit of expanding one good idea into a full subsystem before proving that the subsystem still pays for itself.

## Synthesis

Only transfer what is:

- high leverage
- low coupling
- easy to verify
- directly useful in `pro-nix`

Everything else should stay in `pro.old` as a reference archive or be re-derived later in smaller form.

## What matters most to transfer

### 0. Visual and locale baseline

These are not decorative extras. They define whether the whole system feels native and pleasant.

Transfer or re-create:

- Cyrillic-friendly system and TTY font choices
- UI font defaults with zoom support
- icon support where it actually improves recognition
- a consistently good-looking UI across Emacs and the desktop

Why:

- Russian text must render cleanly everywhere
- font zoom is a daily ergonomic control, not a luxury
- icon support should reduce friction, not become visual noise

#### Useful UI details from `pro.old`

The old config has a few UI ideas that are genuinely worth preserving because they improve day-to-day editing rather than just appearance:

- `shaoline` as a modeline/status layer when available
- `pro-tabs` for consistent `tab-bar` and `tab-line` behavior
- `kind-icon` for completion candidates in `corfu`
- `treemacs-icons-dired` and `nerd-icons-ibuffer` for icon-rich file/buffer views
- `cursor-chg` for readable cursor state in GUI sessions
- `display-line-numbers` only in prog buffers, not everywhere
- `window-divider-mode` and scrollbar cleanup for a calmer frame
- `image+` zoom keys for image buffers
- `transient-posframe` for a cleaner popup workflow
- `yes-or-no-p` -> `y-or-n-p` simplification
- `imenu-auto-rescan` for large buffers

#### Useful text/code details from `pro.old`

For code and project work, the most useful settings are the ones that increase legibility and reduce navigation friction:

- Fira-style ligatures only if they improve readability in code buffers and do not hurt TTY fallback
- `prettify-utils` or similar symbol prettification for selected code/text modes
- `eldoc-box` for compact inline help in GUI sessions
- `consult-project-buffer` and `consult-xref` for project navigation
- `projectile` only if it is already the project root policy you want to keep
- `imenu-auto-rescan` for working in large files
- `display-line-numbers` only in programming buffers
- `org-src-fontify-natively` and `org-pretty-entities` for readable Org code blocks
- `eshell-syntax-highlighting` for shell-like buffers
- prompt/status composition that shows project and git branch when useful

What is most valuable:

- ligatures only in the code font path, not as a global aesthetic rule
- project and xref navigation because they pay off in every repository
- Org source-block readability because this config uses Org as a work surface
- shell highlighting because it lowers mistakes in command-heavy workflows

What to avoid:

- ligatures as a blanket UI fetish across every buffer
- project systems duplicated in parallel
- clever text prettification that hides the underlying code too aggressively

What is most valuable here:

- `shaoline` and `pro-tabs` are not just decoration; they are structural UI layers
- `kind-icon` and iconized dired/ibuffer improve scanning speed
- cursor and line-number policies reduce visual fatigue
- popup and image helpers improve narrow workflows without polluting the core

What should be avoided even if it looks attractive:

- duplicated icon systems in the same space
- too much tab styling if it weakens readability
- per-mode UI tricks that are hard to keep consistent across terminal and GUI

### 1. Agent and service integrations

The useful pieces are the ones that become daily tools, not experiments.

Worth carrying:

- `shaoline` if it is a real git-based workflow tool you actively use
- `pro-tabs` if it is already the preferred tab model
- `elfeed` for reading and triaging feeds
- `telega` for Telegram workflow
- `agent-shell` for agent interaction in buffers

Dialectical note:

- these tools should be integrated as first-class workflows
- they should not turn the config into a plugin warehouse
- if one of them is mostly cosmetic or rarely used, it should stay outside the core

### 2. Language stacks

Transfer the language support that buys real editing speed.

Highest-value targets:

- Lisp
- Python
- C
- Java
- Haskell

For each of these, prefer:

- syntax and indentation correctness
- REPL or eval workflow where relevant
- LSP/eglot only where it genuinely improves navigation and refactoring
- project-aware commands only if they are stable and simple

What matters most:

- Lisp is the configuration language of the system itself
- Python is the highest-friction scripting path in org-babel and system tooling
- C and Java need reliable editing, not heavyweight ceremony
- Haskell should be useful if and only if the toolchain is truly maintained

### 3. Org-mode ergonomics

This should be treated as a core interface, not an optional notes addon.

Transfer the useful part:

- better Org editing defaults
- table handling that stays pleasant
- source block conveniences
- link/capture/navigation helpers
- visual polish that helps structure remain readable

Important principle:

- Org should support work capture, project notes, and config generation
- it should not accumulate redundant UI layers

### 4. Structural editing and parentheses

This is high value for Lisp and for config editing generally.

Keep or add:

- level-aware bracket/paren highlighting
- balanced editing helpers
- useful indentation behavior
- structural editing only if it stays predictable

Why:

- this directly helps the most important languages in the repo
- it reduces mistakes in Emacs Lisp and Nix
- it is a real productivity gain, not decoration

### 5. A minimal user-overridable key contract

This should exist as a small, explicit layer, not as a giant keymap dump.

Target shape:

- ship defaults in `pro-nix`
- let the user replace them from `~/.emacs.d/keys.org`
- keep the runtime loader simple enough that an Org table can define bindings cleanly

Why this matters:

- the user can override keys without editing the system config
- the key layer stays readable and portable
- Org-table storage keeps it human-editable and diff-friendly

Best interpretation:

- `keys.org` stores a table of action -> key -> command
- a small loader reads it into Emacs Lisp
- user-side `keys.org` wins over system defaults

### 6. AI provider policy: aitunnel + openrouter

This is not optional. It is one of the main reasons to carry the old config forward.

What should move:

- minimal `gptel` integration
- default backend selection logic
- OpenRouter and AITunnel provider lists or policies
- a small, current preference order for models

What should not move wholesale:

- huge model catalog tables
- price spreadsheets embedded in runtime config
- vendor encyclopedias that age every week

Desired shape in `pro-nix`:

- one primary AI entrypoint
- one place to define provider preference
- one place to switch between OpenRouter and AITunnel
- everything else stays optional or user-local

### 7. Early-init safety contract

This is the most important migration.

`sample-early-init.el` in `pro.old` already knows the right lesson: Emacs startup must be explicit and defensive. The useful part is not the UI tweaks. It is the prebinding of package/custom variables so Emacs 30+ does not break during bootstrap.

Transfer value:

- `package-enable-at-startup nil`
- early custom-variable prebinding for package-sensitive vars
- minimal frame setup only where it prevents startup regressions

Why this matters:

- it prevents early startup failures
- it makes package loading deterministic
- it fits the current `pro-nix` surface directly

### 8. Nix workflow entrypoints

`про-nix.el` is a strong candidate, but only in reduced form.

Best pieces to keep:

- `nix-mode` mapping
- `envrc` support if the repo actually uses direnv/Nix shells
- a single rebuild command for the active system

Why:

- this repo is Nix-first, so the editor should understand Nix directly
- rebuild is the highest-value action for a NixOS config repo
- the workflow is short, obvious, and testable

What to cut:

- commentary-heavy prose
- extra shell/profile speculation
- anything that assumes a different path layout than `pro-nix`

### 9. Navigation defaults

`про-быстрый-доступ.el` is useful because it lowers the cost of finding things quickly.

Keep the essentials:

- `vertico`
- `orderless`
- `marginalia`
- `consult`
- `consult-xref` integration
- one or two local helper commands like grep-from-here

Why:

- these are stable editor primitives
- they help every future edit, not just one project
- they fit the new repo better than a large custom navigation stack

What not to переносить:

- project-specific wrappers that assume old paths or old naming
- duplicated buffer/project logic if `consult` already covers it

### 10. Dired/file workflow

`про-файлы-и-папки.el` contains real value, but it needs aggressive pruning.

Worth keeping:

- sensible `dired` keybindings
- hide-details and auto-revert defaults
- a small helper to reload local elisp when editing Emacs files

Why:

- file navigation is daily-use glue
- the actions are simple enough to survive a rewrite
- it complements the `emacs/base` split already present in `pro-nix`

What to avoid:

- massive Treemacs configuration unless you already rely on it daily
- decorative options that do not change workflow
- code that drags in extra package complexity for marginal gain

### 11. Terminal ergonomics

`про-терминалы.el` is a good source for practical terminal behavior, but only the parts that solve real pain.

Most valuable pieces:

- sane `vterm` keybindings
- `yank`/`yank-pop` support in terminal buffers
- copy-mode cleanup if you actually use `vterm` heavily
- a compact `eshell` setup if you want an internal shell

Why:

- terminal workflow is part of system-use, not editor ornament
- these fixes are local and reproducible

What to be ruthless about:

- tab-line decoration layers
- heavy face remapping
- large blocks of aesthetic tuning that create maintenance cost

### 12. AI entrypoint, not AI empire

`про-ии-ядро.el` shows what happens when AI integration becomes a model catalog project.

Transfer only the core:

- one `gptel` entrypoint
- backend selection policy
- maybe a small default model preference list

Do not transfer wholesale:

- giant provider/model inventories
- price tables embedded in config logic
- brittle vendor tracking

Reason:

- model catalogs age fast
- config should encode policy, not maintain a market directory
- the useful part is the interaction path, not the encyclopedia

### 13. EXWM session glue

`pro-nix` already has an Emacs/EXWM base, so only keep what improves startup and session control.

Worth keeping:

- minimal EXWM startup wiring
- a small set of global keys
- clear separation between session bootstrap and UI decoration

Do not import:

- large mode-specific behavior unless it is already proven in daily use
- extra EXWM ornamentation that does not help launch reliability

## What is least worth transferring

- long prose comments that explain obvious Emacs behavior
- archived planning documents that belong in `docs/`, not the runtime config
- large AI price/model registries
- Treemacs-heavy layouts and ornamental tab UI
- old path assumptions and repo-specific names
- anything that duplicates what `emacs/base` already does with less code

## Dialectical conclusion

`pro.old` is most valuable as a source of extracted primitives, not as a whole-system template.

The old config proves the following:

- the useful part is the workflow boundary, not the prose around it
- startup safety is more important than feature count
- navigation and rebuild commands deserve to be first-class
- AI support should be small and policy-driven

The practical migration order for `pro-nix` is:

1. visual and locale baseline: Cyrillic fonts, UI fonts, zoom, icons
2. agent and service integrations: `shaoline`, `pro-tabs`, `elfeed`, `telega`, `agent-shell`
3. language stacks: Lisp, Python, C, Java, Haskell
4. Org-mode ergonomics
5. structural editing and parentheses
6. minimal user-overridable key contract via `keys.org`
7. AI provider policy for `aitunnel` and `openrouter`
8. startup safety from `sample-early-init.el`
9. Nix workflow commands
10. consult/vertico navigation
11. minimal dired helpers
12. terminal ergonomics
13. only the simplest EXWM glue

That gives the new repo the best part of the old one without importing its bulk.

## Concrete `pro-nix` implementation plan

### A. Emacs base modules to add or extend

Target split:

- `emacs/base/modules/ui.el` for fonts, icons, scaling, and visual defaults
- `emacs/base/modules/core.el` for common editing defaults and bracket help
- `emacs/base/modules/nix.el` for Nix editing and rebuild commands
- `emacs/base/modules/js.el` or a new `lang.el` for language-specific stacks
- `emacs/base/modules/ai.el` for `gptel`, `openrouter`, `aitunnel`
- a new `emacs/base/modules/org.el` for Org-mode ergonomics
- a new `emacs/base/modules/nav.el` for consult/vertico/orderless/marginalia and search
- a new `emacs/base/modules/keys.el` for user-overridable key loading
- a new `emacs/base/modules/terminal.el` if terminal glue outgrows `exwm.el`

### B. Packages to install in Nix

Likely system packages or Emacs packages:

- `gptel`
- `consult`
- `vertico`
- `orderless`
- `marginalia`
- `elfeed`
- `telega`
- `haskell-language-server`
- `python` tooling already exists, but Emacs-side support should be explicit
- `tree-sitter`-based language modes where needed
- icon/font packages already present, plus a better fallback set if required

### C. Git-based extras

If `shaoline` and `pro-tabs` are real git dependencies, treat them as optional inputs with a clean fallback path.

Recommended policy:

- fetch from git in Nix, not ad hoc in Emacs
- keep the system usable if one of them is absent
- wire them into `ui.el` or a small dedicated module only when available

### D. `keys.org` design

Use a user-owned Org file as the key override surface.

Suggested shape:

- `~/.emacs.d/keys.org`
- a simple table with columns like `section | key | command | note`
- a loader that reads either a system default file or the user file
- user file always wins

Why Org table:

- readable
- easy to edit
- easy to keep in sync with documentation

### E. Org-mode feature list

Add only the useful defaults:

- table navigation and editing helpers
- source block editing support
- startup visibility for headings and emphasis
- capture/agenda links if already used
- nice indentation/visual settings
- make brackets/structure readable rather than flashy

### F. UI baseline

Set up once, then keep it stable:

- Cyrillic-safe font choice
- separate UI font and code font if needed
- scaling/zoom keybinds
- icon theme support in Emacs and desktop
- consistent face defaults for `pro-tabs`, `org`, and completions

### G. Language priority order

Implement in this order:

1. Lisp
2. Nix
3. Python
4. Org
5. C
6. Java
7. Haskell

Reason:

- Lisp and Nix are configuration-critical
- Python is the most practical scripting path
- Org is the system's work surface
- C/Java/Haskell matter, but should not block the core migration

### H. Minimal acceptance rule

Only merge a feature into `pro-nix` if it satisfies at least one of these:

- removes real daily friction
- can be overridden by the user cleanly
- is stable enough to keep in core
- improves editing/search/navigation enough to justify its complexity

This keeps the migration disciplined and prevents `pro-nix` from becoming another accumulation repo.

## Lao-style harmonious plan

The old repo should not be copied as a mass. It should be distilled.

### 1. Keep the center still

Begin with what holds everything together:

- startup safety
- stable editor defaults
- one clear key override path
- one AI policy path

If the center is calm, the rest can move without chaos.

### 2. Let the useful follow the useful

Add only what serves daily work directly:

- Nix editing and rebuild
- navigation and search
- code-language support
- Org-mode ergonomics
- project and git awareness

If a feature does not reduce friction, it is noise.

### 3. Do not force harmony by piling on layers

If two systems do the same job, choose one.

- one tab model
- one completion stack
- one search stack
- one AI entrypoint
- one user key file

Harmony here means fewer contradictions, not more decoration.

### 4. Make the visible things calm

The UI should help without speaking loudly:

- Cyrillic text must render clearly
- fonts must be readable and zoomable
- icons should clarify, not clutter
- ligatures should serve code legibility, not fashion
- cursor, line numbers, and tabs should be restrained

### 5. Honor the old where it is strong

From `pro.old`, keep the patterns that proved themselves:

- `shaoline` if it remains useful as a modeline
- `pro-tabs` if it stays readable
- `consult` family for navigation
- `elfeed`, `telega`, `agent-shell` if they are active daily tools
- `org`-based workflows for notes and tables

Do not preserve habit just because it existed.

### 6. Let the user own the final word

The system should be strong, but not closed.

- user `keys.org` overrides system keys
- user modules override base modules
- optional packages should fail softly
- expensive or niche features should not block the core

### 7. Order of migration

1. UI and text baseline
2. keys.org override path
3. AI provider policy
4. search/navigation
5. Org and code ergonomics
6. language support
7. service integrations
8. only then the ornamental layer

### 8. Final principle

The best config is not the fullest one.

It is the one where every part has a reason, every reason has a place, and the whole remains easy to change.
