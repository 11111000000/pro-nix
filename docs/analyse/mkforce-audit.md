MKForce Audit — findings and actions
=================================

Summary
- We audited usages of lib.mkForce across the repository. Many occurrences are
  legitimate (bootloader, forced fileSystems, policy flags). The most dangerous
  past issue was lib.mkForce used to append to environment.systemPackages in
  modules causing recursion and missing runtime packages. We have already
  migrated the key package-appends for these modules to lib.mkDefault:
  - modules/pro-peer.nix (done)
  - modules/headscale.nix (done)
  - modules/pro-privacy.nix (done)
  - nixos/modules/opencode-system.nix (checked)

Remaining hotspots (manual review recommended)
- configuration.nix: settings.substituters = lib.mkForce [...] — top-level substitution policy; likely intentional.
- modules/pro-storage.nix: services.samba.settings."global" = lib.mkForce { ... } — forced global Samba settings; review for necessity.
- modules/pro-users.nix: security.sudo.extraRules = lib.mkForce ([ ... ]) — forces sudo rules; review for hardening intent.
- hosts/*/configuration.nix: multiple boot.loader, fileSystems set via lib.mkForce — intentional host-level overrides; leave as-is unless operator requests consolidation.
- various modules: ClientTransportPlugin in pro-privacy (kept as mkForce because tor expects explicit lines).

Actionable recommendations (safe, incremental)
1. Continue per-module package-appends migration: ensure no module uses lib.mkForce to append environment.systemPackages. (mostly done)
2. Produce a small PR per remaining mkForce hotspot that:
   - explains Intent/Pressure/Surface/Proof (Change Gate block)
   - either documents why mkForce is required, or replaces with lib.mkDefault/lib.mkAfter/lib.mkMerge where appropriate
   - includes unit tests where feasible

Priority list for review (short):
1) modules/pro-storage.nix — Samba global forced settings. (review; medium risk)
2) modules/pro-users.nix — forced sudo rules. (review; medium risk)
3) configuration.nix settings.substituters — document rationale in docs/ (low risk if intentional)
4) Any other lib.mkForce that forces security-critical options (e.g., users.users.root.openssh.authorizedKeys) — handle carefully with canary and rollback instructions.

Suggested next steps (I can perform)
- I1: Generate a precise list of files/lines with lib.mkForce (machine-readable) and tag each with a suggested action (keep/replace/review). (automated)
- I2: Prepare PR for modules/pro-storage.nix replacing dangerous mkForce with a safer pattern or adding documentation why force is necessary. (manual + small change)
- I3: Run unit CI after each PR and schedule canary deploys where changes affect runtime security (sudo, samba, authorized_keys).

If you approve, I will execute I1 immediately and then I2 (pro-storage) as the next targeted PR.

Date: 2026-04-25
