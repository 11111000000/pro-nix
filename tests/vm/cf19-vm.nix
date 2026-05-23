{ testers, ... }:

let
  baseTest = import ./test-vm-full.nix { inherit testers; };

in testers.nixosTest {
  name = "cf19-vm";
  nodes.machine = { ... }: {
    imports = [ ../hosts/cf19/vm.nix ];
  };
  testScript = baseTest.testScript;
}
