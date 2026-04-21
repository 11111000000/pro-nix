# Join-Secret Specification

Purpose
-------
The join‑secret is a shared secret used during operator‑driven enrollment. It is *not* a password to log in; it is a symmetric secret used to prove operator intent and to protect private artifacts (encrypted WireGuard config, Tor HiddenService keys) that unlock discovery and mesh enrollment.

Design Principles
-----------------
- Never store plaintext secrets in the repository or logs.
- Store only a salted KDF output on the host for verification.
- Allow check from remote via temporary secure copy for verification.

Storage format on host (/etc/pro-peer/join-secret.json)
----------------------------------------------------
File mode: 0600, owner: root

JSON schema:

{
  "kdf": "scrypt",
  "salt": "<base64>",
  "params": { "N": 16384, "r": 8, "p": 1 },
  "hash": "<hex>",
  "created_at": "2026-04-21T12:00:00Z"
}

Notes
-----
- KDF choice: scrypt is recommended; parameters chosen to balance CPU cost and usability.
- Verification: proctl.check-join-secret computes KDF(secret, salt, params) and compares the resulting hex digest to stored hash.
- Rotation: proctl.set-join-secret replaces join-secret atomically; proctl must create a backup of the old /etc/pro-peer/join-secret.json before overwriting.

Remote verification
-------------------
- For remote hosts, proctl.check-join-secret will scp the join-secret.json to a temporary path on controller machine, perform local KDF check, then delete the temporary file. It does not transmit the secret.

Security considerations
-----------------------
- Do not log the secret or derived material.
- Salt must be randomly generated per host.
- Consider hardware-backed key storage for higher assurance in production.
