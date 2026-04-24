SURFACE — Public contract registry
================================

Entries:

- Name: Healthcheck
  Stability: [FROZEN]
  Spec: repository exposes a reproducible verification entrypoints: `just` or `scripts/emacs-sync.sh`. Proof: `tests/contract/test_surface_health.spec`

- Name: Soft Reload (Emacs)<BR>
  Stability: [FROZEN]
  Spec: provide `pro.emacs.softReload.enable` option and headless ERT that exercises reload. Proof: headless ERT runner (see HOLO.md)

- Name: Pro-peer Key Sync
  Stability: [FLUID]
  Spec: `pro-peer.enableKeySync` controls a systemd service `pro-peer-sync-keys` and a template script `scripts/pro-peer-sync-keys.sh`. Proof: `scripts/pro-peer-sync-keys.sh` and systemd timer unit behaviour.
