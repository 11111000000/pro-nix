#!/usr/bin/env python3
"""
Textual TUI для управления pro-nix (MVP prototype).

Это минималистичный интерфейс, использующий proctl как backend. Пока
поддерживает: список хостов, host status, list services и run-script preview.

Комментарии и docstrings на русском.
"""

from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static, Button, Input, TextLog, Label
from textual.containers import Horizontal, Vertical
from textual.widget import Widget
from textual.reactive import reactive
import subprocess
import json
import os
import shlex

PROCTL = os.path.join(os.path.dirname(os.path.dirname(__file__)), "proctl/cli.py")


def call_proctl(args):
    cmd = [PROCTL] + args
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        try:
            return {"error": p.stderr.decode(errors="replace")}
        except Exception:
            return {"error": str(p.stderr)}
    try:
        return json.loads(p.stdout.decode(errors="replace"))
    except Exception as e:
        return {"error": f"parse error: {e}", "raw": p.stdout.decode(errors="replace")}


class HostsTree(Static):
    """Панель списка хостов"""
    def compose(self) -> ComposeResult:
        # В простом прототипе hosts отражаются через кнопку Refresh
        yield Label("Список хостов обновляется по нажатию кнопки 'Refresh Hosts'")


class OnboardWizard(Widget):
    """Простой интерактивный визард для первичной настройки хоста.

    Шаги:
      1) Ввод hostname
      2) Указание пути к authorized_keys.gpg (локальный)
      3) Preview и запуск загрузки и синхронизации
    """
    step = reactive(1)

    def compose(self) -> ComposeResult:
        yield Label("Onboarding Wizard — шаг 1/3", id="wizard_title")
        yield Label("Шаг 1: укажите хост (local или ssh:user@host:port) и (опционально) новое имя хоста")
        yield Label("Host spec:")
        yield Input(placeholder="local", id="host_input")
        yield Label("Новый hostname (оставьте пустым чтобы не менять):")
        yield Input(placeholder="hostname.local", id="hostname_input")
        yield Label("Выполнять с правами root на целевом хосте?")
        yield Button("Run as root: OFF", id="as_root_toggle")
        yield Button("Далее", id="wizard_next")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Универсальная обработка нажатий в визарде.

        Обрабатываем переключение run-as-root, навигацию шагов, проверку/установку секрета,
        запуск действий и отмену.
        """
        # Toggle as-root
        if event.button.id == "as_root_toggle":
            cur = getattr(self, 'as_root', False)
            self.as_root = not cur
            event.button.label = f"Run as root: {'ON' if self.as_root else 'OFF'}"
            return

        # Next button navigation
        if event.button.id == "wizard_next":
            if self.step == 1:
                host_inp = self.query_one("#host_input", Input)
                self.host_spec = host_inp.value.strip() or "local"
                inp = self.query_one("#hostname_input", Input)
                self.hostname = inp.value.strip()
                self.step = 2
                self.mount_step2()
            elif self.step == 2:
                # require secret validation before proceeding
                if not getattr(self, 'secret_valid', False):
                    self.app.main_log.write("Сначала проверьте секрет или установите его на хосте.")
                    return
                self.step = 3
                self.mount_step3()
            elif self.step == 3:
                # move to preview/confirm step
                self.step = 4
                self.mount_step3()
            return

        # Validate join-secret on the target host
        if event.button.id == "wizard_validate_secret":
            try:
                secret = self.query_one("#secret_input", Input).value.strip()
            except Exception:
                secret = ""
            if not secret:
                self.app.main_log.write("Секрет не введён")
                return
            self.app.main_log.write("Проверяем секрет на хосте...")
            import asyncio

            async def do_check():
                res = await asyncio.to_thread(call_proctl, ["check-join-secret", "--host", getattr(self, 'host_spec', 'local'), "--secret", secret])
                if res.get('ok'):
                    self.secret_valid = True
                    self.app.main_log.write("Секрет валиден — можно продолжать")
                else:
                    self.secret_valid = False
                    self.app.main_log.write("Секрет не прошёл проверку: %s" % str(res.get('error', res)))

            asyncio.create_task(do_check())
            return

        # Set join-secret on the target host (operator action)
        if event.button.id == "wizard_set_secret":
            try:
                secret = self.query_one("#secret_input", Input).value.strip()
            except Exception:
                secret = ""
            if not secret:
                self.app.main_log.write("Секрет не введён")
                return
            self.app.main_log.write("Устанавливаем секрет на хосте (operator)...")
            import asyncio

            async def do_set():
                res = await asyncio.to_thread(call_proctl, ["set-join-secret", "--host", getattr(self, 'host_spec', 'local'), "--secret", secret])
                self.app.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
                # auto-validate
                res2 = await asyncio.to_thread(call_proctl, ["check-join-secret", "--host", getattr(self, 'host_spec', 'local'), "--secret", secret])
                if res2.get('ok'):
                    self.secret_valid = True
                    self.app.main_log.write("Секрет записан и проверен.")
                else:
                    self.secret_valid = False
                    self.app.main_log.write("Ошибка валидации после установки: %s" % str(res2.get('error', res2)))

            asyncio.create_task(do_set())
            return

        # Execute (final run) handled below

    def mount_step2(self):
        self.clear()
        self.mount(Label("Onboarding Wizard — шаг 2/3"))
        self.mount(Label("Шаг 2: укажите локальный путь до authorized_keys.gpg или оставьте пустым"))
        self.mount(Input(placeholder="/path/to/authorized_keys.gpg", id="key_input"))
        self.mount(Button("Далее", id="wizard_next"))

    def mount_step3(self):
        self.clear()
        self.clear()
        self.mount(Label("Onboarding Wizard — шаг 3/4"))
        self.mount(Label(f"Host: {getattr(self, 'host_spec', 'local')}"))
        self.mount(Label(f"Hostname: {getattr(self, 'hostname', '')}"))
        self.mount(Label(f"Keys: {getattr(self, 'keypath', '')}"))
        self.mount(Label("Preview действий:"))
        preview_lines = []
        if getattr(self, 'hostname', ''):
            preview_lines.append(f"hostnamectl set-hostname {self.hostname}")
        if getattr(self, 'keypath', ''):
            preview_lines.append(f"upload {self.keypath} -> /etc/pro-peer/authorized_keys.gpg")
            preview_lines.append("run pro-peer-sync-keys")
        for ln in preview_lines:
            self.mount(Label(ln))
        # Options for discovery and overlay
        self.enable_avahi = False
        self.mount(Label("Опции включения discovery (будут применяться после подтверждения):"))
        self.mount(Button("Enable Avahi on overlay: OFF", id="toggle_avahi"))
        self.mount(Label("WireGuard config (локальный путь, опционально):"))
        self.mount(Input(placeholder="/path/to/wg0.conf", id="wg_input"))
        self.mount(Label("(Tor hidden service: загрузите зашифрованный blob вручную и распакуйте через оператора)"))
        # Confirmation
        self.mount(Label("Для выполнения введите слово 'APPLY' в поле ниже и нажмите 'Выполнить'"))
        self.mount(Input(placeholder="APPLY", id="confirm_input"))
        self.mount(Button("Выполнить", id="wizard_run"))
        self.mount(Button("Отмена", id="wizard_cancel"))

    def on_mount(self) -> None:
        # focus hostname input initially
        try:
            self.query_one(Input).focus()
        except Exception:
            pass

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "wizard_next":
            # handled above
            return
        if event.button.id == "wizard_run":
            # confirmation required
            try:
                confirm = self.query_one("#confirm_input", Input).value.strip()
            except Exception:
                confirm = ""
            if confirm != "APPLY":
                self.app.main_log.write("Подтверждение не введено или неверно. Введите 'APPLY' в поле подтверждения.")
                return
            # perform actions asynchronously
            import asyncio

            asyncio.create_task(self.perform_actions_async())
        if event.button.id == "wizard_cancel":
            self.remove()
        if event.button.id == "toggle_avahi":
            cur = getattr(self, 'enable_avahi', False)
            self.enable_avahi = not cur
            event.button.label = f"Enable Avahi on overlay: {'ON' if self.enable_avahi else 'OFF'}"
            return

    async def perform_actions_async(self):
        host = getattr(self, 'host_spec', 'local')
        self.app.main_log.clear()
        self.app.main_log.write("Запуск Onboarding действий...")
        # Step: set hostname
        if getattr(self, 'hostname', ''):
            self.app.main_log.write(f"Выполняем set-hostname {self.hostname} на {host} (pkexec={getattr(self,'as_root',False)})")
            cmd = ["set-hostname", "--host", host, "--hostname", self.hostname]
            if getattr(self, 'as_root', False):
                cmd += ["--as-root"]
            res = await asyncio.to_thread(call_proctl, cmd)
            self.app.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
        # Step: upload keys
        if getattr(self, 'keypath', ''):
            self.app.main_log.write(f"Загружаем ключи {self.keypath} -> /etc/pro-peer/authorized_keys.gpg на {host}")
        cmd = ["upload-file", "--host", host, "--src", self.keypath, "--dst", "/etc/pro-peer/authorized_keys.gpg"]
            if getattr(self, 'as_root', False):
                cmd += ["--as-root"]
            res2 = await asyncio.to_thread(call_proctl, cmd)
            self.app.main_log.write(json.dumps(res2, ensure_ascii=False, indent=2))
            # if backup present, surface restore option
            backup = None
            try:
                backup = res2.get('result', {}).get('backup')
            except Exception:
                backup = None
            if backup:
                self.app.main_log.write("Backup created: " + str(backup))
                self.app.main_log.write("Чтобы восстановить, используйте proctl restore-backup --host ... --backup <path> --dst <dst>")
            # run sync
            self.app.main_log.write("Запускаем pro-peer-sync-keys")
            cmd3 = ["run-script", "--host", host, "--script", "pro-peer-sync-keys"]
            if getattr(self, 'as_root', False):
                cmd3 += ["--as-root"]
            res3 = await asyncio.to_thread(call_proctl, cmd3)
            self.app.main_log.write(json.dumps(res3, ensure_ascii=False, indent=2))
        # WireGuard deploy step
        try:
            wgpath = self.query_one("#wg_input", Input).value.strip()
        except Exception:
            wgpath = ""
        if wgpath:
            self.app.main_log.write(f"Deploying WireGuard config {wgpath} to {host}")
            up_cmd = ["upload-file", "--host", host, "--src", wgpath, "--dst", "/etc/wireguard/wg0.conf"]
            if getattr(self, 'as_root', False):
                up_cmd += ["--as-root"]
            up_res = await asyncio.to_thread(call_proctl, up_cmd)
            self.app.main_log.write(json.dumps(up_res, ensure_ascii=False, indent=2))
            # bring up wg
            bring_cmd = ["exec", "--host", host, "--cmd", "wg-quick up wg0"]
            if getattr(self, 'as_root', False):
                bring_cmd += ["--as-root"]
            bring_res = await asyncio.to_thread(call_proctl, bring_cmd)
            self.app.main_log.write(json.dumps(bring_res, ensure_ascii=False, indent=2))
        # enable avahi on overlay if requested
        if getattr(self, 'enable_avahi', False):
            self.app.main_log.write("Enabling Avahi on overlay (enable-discovery)")
            en_cmd = ["enable-discovery", "--host", host, "--enable"]
            if getattr(self, 'as_root', False):
                en_cmd += ["--as-root"]
            en_res = await asyncio.to_thread(call_proctl, en_cmd)
            self.app.main_log.write(json.dumps(en_res, ensure_ascii=False, indent=2))
        self.app.main_log.write("Onboarding завершён.")
        # remove wizard widget
        self.remove()


class MainApp(App):
    CSS_PATH = ""

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical():
                yield Static("Hosts", id="hosts_label")
                self.tree = TreeControl("Hosts", {})
                yield self.tree
                yield Button("Refresh Hosts", id="refresh_hosts")
            with Vertical():
                yield Static("Main", id="main_label")
                self.main_log = TextLog()
                yield self.main_log
                yield Button("Host Status", id="host_status")
                yield Button("List Services", id="list_services")
                yield Button("Run Onboarding Wizard", id="onboard_wizard")
                yield Button("Run Pro-peer Sync (preview)", id="run_sync")
        yield Footer()

    def on_mount(self):
        # initial load hosts
        self.load_hosts()

    def load_hosts(self):
        res = call_proctl(["list-hosts"])
        self.tree.root.clear()
        if "hosts" in res:
            for h in res["hosts"]:
                self.tree.root.add(h["name"], h)
        else:
            self.main_log.write(f"Error loading hosts: {res.get('error')}")

    async def on_button_pressed(self, event):
        id = event.button.id
        if id == "refresh_hosts":
            self.load_hosts()
        elif id == "host_status":
            # find selected host or default local
            host = "local"
            res = call_proctl(["host-status", "--host", host])
            self.main_log.clear()
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
        elif id == "list_services":
            host = "local"
            res = call_proctl(["list-services", "--host", host])
            self.main_log.clear()
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
        elif id == "run_sync":
            host = "local"
            res = call_proctl(["run-script", "--host", host, "--script", "pro-peer-sync-keys", "--dry-run"])
            self.main_log.clear()
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
        elif id == "onboard_wizard":
            # Simple linear wizard prototype: set hostname, upload keys, sync
            host = "local"
            # Step 1: ask hostname via input (blocking for prototype)
            from textual.widgets import Input
            self.main_log.write("--- Onboarding Wizard ---\n")
            self.main_log.write("Шаг 1: введите hostname (или оставьте пустым): ")
            # For prototype, we read from ENV or use example
            newname = os.environ.get("PRO_NIX_TEST_HOSTNAME", "")
            if newname:
                self.main_log.write(f"(использован тестовый hostname: {newname})\n")
                res = call_proctl(["set-hostname", "--host", host, "--hostname", newname, "--dry-run"]) 
                self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
            else:
                self.main_log.write("(нет hostname; пропускаем)\n")
            # Step 2: keys upload (preview)
            self.main_log.write("Шаг 2: preview upload authorized_keys.gpg (используйте PRO_NIX_TEST_KEY env для пути)\n")
            src = os.environ.get("PRO_NIX_TEST_KEY", "")
            if src and os.path.exists(src):
                res = call_proctl(["upload-file", "--host", host, "--src", src, "--dst", "/etc/pro-peer/authorized_keys.gpg", "--dry-run"]) 
                self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))
            else:
                self.main_log.write("(нет тестового ключа; пропускаем загрузку)\n")
            # Step 3: sync preview
            res = call_proctl(["run-script", "--host", host, "--script", "pro-peer-sync-keys", "--dry-run"]) 
            self.main_log.write(json.dumps(res, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    app = MainApp()
    app.run()
