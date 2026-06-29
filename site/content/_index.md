+++
title = "про-nix"
weight = 1

[extra]
tldr = "Переносимый стек NixOS + Emacs + AI-агенты. Декларативно. Идемпотентно. С явной позицией."
+++

<header class="hero">
  <h1 class="hero-title">про<span class="accent">-</span>nix</h1>
  <p class="hero-sub">Переносимый стек NixOS + Emacs + AI-агенты.</p>
  <p class="hero-tag"><strong>Декларативно. Идемпотентно. С явной позицией. Прозрачно.</strong></p>
</header>

<div class="tldr">
  <strong>TL;DR</strong>
  <p>Один репозиторий, четыре машины, одна клавиатурная философия
  в трёх оконных менеджерах, и Emacs с поддержкой LLM, которым можно
  управлять из <code>pi</code>, <code>opencode</code> или MCP-инструментов.
  Всё на Nix; после <code>just switch</code> ничего не правится руками.</p>
</div>

<div class="grid-3">
  <div class="card">
    <div class="badge">ХОСТЫ</div>
    <h3>4 машины</h3>
    <p><a href="/hosts/">desktop</a>, <a href="/hosts/cf19/">cf19</a>, <a href="/hosts/huawei/">huawei</a>, <a href="/hosts/vm/">vm</a> — один flake, четыре host-конфига, четыре характера.</p>
  </div>
  <div class="card">
    <div class="badge">СТЕК</div>
    <h3>3 слоя</h3>
    <p>NixOS-система, Emacs-редактор, AI-агенты. Каждый слой декларативен и имеет свою историю bootstrap и reload.</p>
  </div>
  <div class="card">
    <div class="badge">WM</div>
    <h3>1 клавиатура</h3>
    <p>EXWM в Emacs, Sway на Wayland, i3 на X11 — три оконных менеджера, одна раскладка клавиш (<code>Mod4+hjkl</code>, <code>Mod4+1..9</code>, …).</p>
  </div>
</div>

<h2>Выберите нить</h2>
<div class="grid-2">
  <div class="card">
    <h3><a href="/about/">Что такое pro-nix</a></h3>
    <p>Один абзац про суть, цели, анти-цели и то, чем этот репозиторий сознательно не является.</p>
  </div>
  <div class="card">
    <h3><a href="/principles/">Принципы</a></h3>
    <p>Пять сквозных принципов (декларативность, идемпотентность, единственный источник правды, opinionated + прозрачность, композиция слоёв), которыми руководствуется каждое решение в репо.</p>
  </div>
  <div class="card">
    <h3><a href="/stack/">Стек</a></h3>
    <p>Что выбрано и почему. NixOS pin, 64 Emacs-модуля, <code>pi</code> + <code>opencode</code>, Tor-стек.</p>
  </div>
  <div class="card">
    <h3><a href="/architecture/">Архитектура</a></h3>
    <p>Как слои стыкуются. Flake inputs, модули, composition-файлы, bootstrap Emacs, сетевые слои.</p>
  </div>
  <div class="card">
    <h3><a href="/hosts/">Хосты</a></h3>
    <p>Четыре машины, четыре design-story. Какая аппаратная особенность продиктовала какой kernel-параметр, какую mount-опцию, какой composition-файл.</p>
  </div>
  <div class="card">
    <h3><a href="/reference/">Справочник</a></h3>
    <p>Автогенерируемые каталоги: NixOS-опции, <code>defcustom</code>, клавиши, скрипты, сабмодули, тесты, CI.</p>
  </div>
  <div class="card">
    <h3><a href="/workflow/">Рабочий процесс</a></h3>
    <p>Как жить с репозиторием день за днём. <code>just</code>-рецепты, политика сабмодулей, soft-reload, troubleshooting.</p>
  </div>
  <div class="card">
    <h3><a href="/conventions/">Соглашения</a></h3>
    <p>Governance: формат коммитов, <code>mkForce</code> vs <code>mkDefault</code>, Change-Gate, детекторы мёртвого кода, анти-паттерны.</p>
  </div>
</div>

<h2>Прочти это, если не прочтёшь ничего другого</h2>
<ul>
  <li><a href="/about/">Что такое pro-nix и чем он не является</a></li>
  <li><a href="/principles/">5 принципов</a></li>
  <li><a href="/workflow/quickstart/">Быстрый старт: <code>just switch</code></a></li>
  <li><a href="/conventions/anti-patterns/">Анти-паттерны (чего не делать)</a></li>
</ul>
