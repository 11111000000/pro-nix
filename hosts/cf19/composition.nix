{ lib, ... }:

{
  # CF-19 использует EXWM как минимальную графическую среду и отдельно
  # получает компактный прикладной desktop-слой без тяжёлого desktop branch.
  pro.profiles.exwmMinimal.enable = lib.mkDefault true;
}
