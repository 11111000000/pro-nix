+++
title = "pro-nix"
weight = 1

[extra]
tldr = "Portable NixOS + Emacs + AI-agents stack. Declarative, idempotent, opinionated. Transparent."
+++

<header class="hero">
  <h1 class="hero-title">pro<span class="accent">-</span>nix</h1>
  <p class="hero-sub">Portable NixOS + Emacs + AI-agents stack.</p>
  <p class="hero-tag"><strong>Declarative. Idempotent. Opinionated. Transparent.</strong></p>
</header>

<div class="tldr">
  <strong>TL;DR</strong>
  <p>One repo, four machines, one keyboard philosophy across three
  window managers, and an LLM-ready Emacs that you can drive from
  <code>pi</code>, <code>opencode</code>, or MCP tools. Everything is
  Nix; nothing is hand-edited after <code>just switch</code>.</p>
</div>

<div class="grid-3">
  <div class="card">
    <div class="badge">HOSTS</div>
    <h3>4 machines</h3>
    <p><a href="/en/hosts/">desktop</a>, <a href="/en/hosts/cf19/">cf19</a>, <a href="/en/hosts/huawei/">huawei</a>, <a href="/en/hosts/vm/">vm</a> — one flake, four host configs, four personalities.</p>
  </div>
  <div class="card">
    <div class="badge">STACK</div>
    <h3>3 layers</h3>
    <p>NixOS system, Emacs editor, AI agents. Each layer is declarative and has its own bootstrap and reload story.</p>
  </div>
  <div class="card">
    <div class="badge">WM</div>
    <h3>1 keyboard</h3>
    <p>EXWM in Emacs, Sway on Wayland, i3 on X11 — three window managers, one keymap (<code>Mod4+hjkl</code>, <code>Mod4+1..9</code>, …).</p>
  </div>
</div>

<h2>Pick a thread</h2>
<div class="grid-2">
  <div class="card">
    <h3><a href="/en/about/">What is pro-nix</a></h3>
    <p>One paragraph about the gist, goals, anti-goals, and what this repo deliberately is not.</p>
  </div>
  <div class="card">
    <h3><a href="/en/principles/">Principles</a></h3>
    <p>Five cross-cutting principles (declarative, idempotent, single source of truth, opinionated + transparent, composed layers) that guide every decision in the repo.</p>
  </div>
  <div class="card">
    <h3><a href="/en/stack/">Stack</a></h3>
    <p>What's chosen and why. NixOS pin, 64 Emacs modules, <code>pi</code> + <code>opencode</code>, Tor stack.</p>
  </div>
  <div class="card">
    <h3><a href="/en/architecture/">Architecture</a></h3>
    <p>How the layers fit together. Flake inputs, modules, composition files, Emacs bootstrap, network layers.</p>
  </div>
  <div class="card">
    <h3><a href="/en/hosts/">Hosts</a></h3>
    <p>Four machines, four design stories. Which hardware quirk dictated which kernel parameter, which mount option, which composition file.</p>
  </div>
  <div class="card">
    <h3><a href="/en/reference/">Reference</a></h3>
    <p>Auto-generated catalogues: NixOS options, <code>defcustom</code>, keybindings, scripts, submodules, tests, CI.</p>
  </div>
  <div class="card">
    <h3><a href="/en/workflow/">Workflow</a></h3>
    <p>How to live with the repo day to day. <code>just</code> recipes, submodule policy, soft-reload, troubleshooting.</p>
  </div>
  <div class="card">
    <h3><a href="/en/conventions/">Conventions</a></h3>
    <p>Governance: commit format, <code>mkForce</code> vs <code>mkDefault</code>, Change-Gate, dead-code detectors, anti-patterns.</p>
  </div>
</div>

<h2>Read this if you read nothing else</h2>
<ul>
  <li><a href="/en/about/">What is pro-nix and what it isn't</a></li>
  <li><a href="/en/principles/">5 principles</a></li>
  <li><a href="/en/workflow/quickstart/">Quick start: <code>just switch</code></a></li>
  <li><a href="/en/conventions/anti-patterns/">Anti-patterns (what not to do)</a></li>
</ul>
