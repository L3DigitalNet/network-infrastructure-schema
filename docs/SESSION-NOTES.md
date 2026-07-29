# Session Notes

Tactical, append-only continuity log for agents working this repo. **Read this at the start of a session; append a dated entry at the end of any substantive one (newest first).**

**Scope vs [`PROJECT-STATUS-AND-ROADMAP.md`](PROJECT-STATUS-AND-ROADMAP.md):** that file holds the big picture — roadmap, completed deliverables, and the dated change-log of _what_ shipped. This file holds the finer grain it doesn't: _why_ a decision went the way it did, gotchas that cost time, the current mental model, and open threads to resume. When a fact graduates to durable project status, move it there and keep only the tactical residue here.

---

## Durable gotchas & mental model

Non-obvious facts that bite. True across sessions until the code itself changes. Add to this list whenever something costs you more than a few minutes to (re)discover.

- **The JSON Schema is generated, not hand-authored.** `schemas/infra.schema.json` is emitted by `_build/build_schema.py` (it `write_text`s the file at the end). To change the schema, edit the **builder** and re-run `uv run python _build/build_schema.py`, then re-run validation stages 1–4. Hand-edits to the JSON are silently overwritten on the next build.
- **`format` is annotation-only, repo-wide.** Both `validate_examples.py` and the drift gate build `Draft202012Validator(SCHEMA)` with **no** `format_checker`, so `format: ipv4|ipv6|hostname|uri` is documentation, not enforcement. IP/CIDR _shape_ is enforced by `pattern` (the `Cidr`/`IpAddress` `$def`s) and, on the Pydantic side, by `AfterValidator` on the `IpAddress`/`Cidr` type aliases — never rely on `format` to reject anything.
- **`IpConfig.address` is special:** it accepts the literal `"dhcp"` OR a CIDR (schema `$ref IpOrDhcp`), via a dedicated `@field_validator`. Don't retype it to a plain `Cidr` alias — that would reject `"dhcp"`.
- **`from __future__ import annotations` is active in `infra_models.py`.** A naive static scan of a field's `metadata` will MISS its `AfterValidator` (annotations are stringized and/or nested under `Optional`). Verify field validation **behaviorally** — run `DocumentAdapter.validate_python` on a bad value — not by introspecting annotations. (This caused a false "fix-3 missed a field" alarm in review; behavioral testing cleared it.)
- **conftest runs one closed-world unit per invocation.** `conftest test --combine` over BOTH manifests fails by design — they intentionally re-declare shared fixtures, so pooling creates duplicate composite keys. Run per-manifest. `python infra_models.py --merge` over both manifests fails for the same reason; that is expected, not a regression.
- **Benign uv warning:** `VIRTUAL_ENV=/usr … will be ignored` prints on every `uv run` (this box exports `VIRTUAL_ENV` globally). uv correctly uses the project `.venv`. Not a failure.
- **Frontmatter ID helper vs uv shim:** Project Standards 5.11.0's managed
  `new-doc-id` helper invokes bare `python3`, which the workstation's uv-strict
  shim rejects. Until upstream issue
  [#97](https://github.com/L3DigitalNet/project-standards/issues/97) is fixed, run
  only that helper with `PATH="/usr/bin:$PATH"`; do not edit the lock-owned script
  or disable the shim globally.
- **Drift gate scope boundaries** — a green gate does NOT mean these agree; they are deliberately out of scope: cross-field graph checks (owned by Pydantic stage-3 + OPA stage-4), explicit `null` on optional fields (JSON Schema rejects `field: null`; Pydantic accepts; real docs omit optionals), and IPv4-mapped IPv6 (`::ffff:…`, accepted by `ip_address()` but rejected by the hex-colon pattern).

---

## Session log

### 2026-07-29 — Project Standards 5.11.0 fresh adoption

**Outcome.** Initialized Catalog 5 and adopted exact
`markdown-frontmatter@1.6`, scoped to the already-declared
`docs/research/**/*.md` corpus. Reconciliation installed the managed authoring
skill, ID helper, package summary, and `@v5` reusable validation caller. Added
contract-1.1 metadata to the existing research report. No legacy Agent Handoff
layer existed, and no schema, policy, example, Python-tooling, or custom
session-continuity behavior changed.

**Selection rationale.** Frontmatter was the only package backed by explicit
repository intent. Python Tooling was not selected because this deliberately
non-installable repo uses plain validation scripts and has no pytest suite.
Markdown Tooling, ADR, Project Spec, CLI Documentation, and Agent Handoff were
also left disabled rather than inventing new repository intent.

**Release friction.** The first post-install version probe transiently failed
inside Pydantic but a retry verified 5.11.0
([#96](https://github.com/L3DigitalNet/project-standards/issues/96)). The managed
Frontmatter 1.6 docs still link to v5.10.0; fresh-adoption evidence was added to
[#53](https://github.com/L3DigitalNet/project-standards/issues/53). The exact-tag
versioning policy still names 5.10.0; corroboration was added to
[#85](https://github.com/L3DigitalNet/project-standards/issues/85). The managed ID
helper is incompatible with the workstation uv shim; reported as
[#97](https://github.com/L3DigitalNet/project-standards/issues/97) and worked
around only for ID generation with `/usr/bin` first in `PATH`.

**Verification.** The pre-adoption repository gate was green through stages
1–4d. After adoption, `project-standards validate`,
`format-frontmatter --check`, and `project-standards reconcile --check --json`
all passed; the reconciliation JSON reported `ok: true`, `drift: false`, no
findings, and only the understood create-only workflow `preserve` actions. The
full repository gate also passed through isolated OpenTofu validation, which
resolved bpg/proxmox 0.111.1 and prompted the moving tool-version references to
be refreshed.

### 2026-06-03 — Schema↔Pydantic drift gate (Phase 1 #1 + #3)

**Outcome.** Built `_build/check_drift.py` — components **C1** (valid-corpus agreement), **C2** (15-file `examples/invalid/` negative corpus), **C4** (kind-set / required-field / closedness parity) — plus three D6 conformance fixes. Gate is green; wired into CI as stage 4b. Pushed to `origin/main` (`9c4c7d8`…`83773db`: design artifacts + 8 implementation commits). Roadmap §6 #1 & #3 marked done.

**Process.** brainstorm → `/qdev:research` ×2 (approach comparison; polyfactory viability) → spec → `/qdev:quality-review` on the spec (2 rounds) → writing-plans → `/qdev:quality-review` on the plan (empirical) → subagent-driven execution (fresh implementer + spec-then-quality review per task). Artifacts: spec `docs/superpowers/specs/2026-06-03-schema-pydantic-drift-gate-design.md`, plan `docs/superpowers/plans/2026-06-03-schema-pydantic-drift-gate.md`, research `docs/research/2026-06-02-json-schema-pydantic-drift-gate.md`.

**Decisions + rationale (the non-obvious ones):**

- **Hybrid gate, not schema-diff or pure property-testing.** Research ruled both out: `hypothesis-jsonschema` has no Draft 2020-12 support; no tool semantically diffs differently-encoded 2020-12 schemas; reconciling `if/then` vs discriminated `oneOf` is undecidable in general. So: behavioral corpus (C1/C2) + a narrow structural check (C4).
- **The gate's construction found 3 real contract bugs** (the headline — a one-time audit, not just ongoing protection). **fix-1:** `_validate_cidr` accepted prefix-less CIDRs the schema rejects. **fix-2:** the `IpAddress` `$def` was `format`-only → unenforced, so the schema accepted `not-an-ip`. **fix-3** (surfaced by the C3 spike): ~12 `IpAddress`/`Cidr`-typed fields were bare `str` in Pydantic, so once fix-2 made the schema strict, Pydantic was broader on all of them. All fixed by carrying `AfterValidator` on the type aliases + retyping the fields. Classified **PATCH** under the stated interpretation "valid = conformant under BOTH validators" (no such document existed; verified no example or `../network-infrastructure/` consumer used the lax forms).
- **C3 (polyfactory generative component) deferred** — twice, for different reasons. Attempt 1 surfaced the fix-3 drift (real → fixed). Attempt 2 (post-fix) surfaced explicit-`null`-on-optionals "drift", which is a **benign modeling difference**, not a bug (real documents omit optionals; they never write explicit `null`). C3 needs `exclude_none=True` serialization + ~6–8 custom providers to be viable. Deferred as a documented fast-follow rather than chasing a schema change for a value no real doc uses.

**Open threads / next-up:**

- **Phase 1 #2 — real fixtures.** Replace `.example` domains/addressing with true L3D values; move into a `live/` tree validated in `--merge` mode. Last Phase-1 item gating the Phase-2 generators.
- **C3 fast-follow.** Re-attempt the generative component with `exclude_none=True` + the ~6–8 providers; first settle the explicit-`null` modeling decision (tighten Pydantic, make the schema nullable, or keep it a documented boundary — current lean: keep as boundary).
