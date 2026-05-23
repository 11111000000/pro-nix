{ testers, ... }:

# Облегчённый cf19-like VM: используем ту же VM-конфигурацию, что и test-vm-full,
# но отключаем любые host-specific модули (pro-users, Emacs, opencode и т.п.).

let
  baseTest = import ./test-vm-full.nix { inherit testers; };

in testers.nixosTest {
  name = "cf19-vm-light";

  # Ноды такие же, как в базовом тесте, чтобы не тащить host-специфичную политику.
  nodes.machine = baseTest.nodes.machine;

  testScript = baseTest.testScript;
}
