# infra-schema — Project Status & Roadmap

Status record for the L3D desired-state infrastructure schema pack (`infra.luminous3d.example/v1alpha1`, repo version v0.1.0). Formatted for LLM consumption: status tags, explicit file paths, tables over prose. This is the hand-off artifact for Claude Code (implementer) to plan iteration against.

- Built as `infra-schema` in the build environment at `/home/claude/infra-schema/`; now lives in this repo at `/home/chris/projects/network-infrastructure-schema/`.
- Delivered outputs (build environment): `/mnt/user-data/outputs/` (+ `infra-schema-v0.1.0.zip`)
- Build session date: 2026-06-02
- Repository standards: Project Standards 5.11.0, Catalog 5, exact
  `markdown-frontmatter@1.6` over `docs/research/**/*.md`.

---

## 1. Original prompt

The verbatim (reconstructed) original prompt lives in [`docs/original-prompt.md`](original-prompt.md). It was reconstructed after the build session — the original attachment text was not retained in working context (see §4).

---

## 2. Completed

All items below were **built as real files and validated with real tools** in the build environment. Validation commands and versions are in `README.md` §4 and `ci/pipeline.md`.

| Deliverable | Path | Validated with | Status |
| --- | --- | --- | --- |
| JSON Schema 2020-12 (44 `$defs`, envelope, per-kind `if/then`, `oneOf[Object,Bundle]`) | `schemas/infra.schema.json` | `jsonschema` 4.26.0; 21 docs pass; 8 negative cases correctly rejected | DONE |
| Pydantic v2 models + graph layer + CLI (`--check`/`--merge`/`--emit-schema`) | `python/infra_models.py` | `pydantic` 2.13.4; all examples + both manifests pass; `--emit-schema` emits 65 defs | DONE |
| 19 per-kind YAML examples | `examples/kinds/*.yaml` | schema + yamllint | DONE |
| 2 multi-object manifests (single-site; multi-site+failover) | `examples/manifests/{site-home,multi-site-failover}.yaml` | schema + Pydantic graph + 9/9 policy each | DONE |
| 5 OPA/Rego guardrail policies + shared lib | `policies/opa/{exposure,backup,privileged,zone_isolation,ip_prefix}.rego`, `policies/opa/lib/objects.rego` | `conftest` 0.56.0 / OPA 0.69.0 | DONE |
| 15 policy unit tests | `policies/opa/policy_test.rego` | `conftest verify` → 15/15 | DONE |
| Conftest config + policy catalog | `policies/conftest/{conftest.toml,README.md}` | used by conftest runs | DONE |
| NetBox mapping guide (two-pass seed, bulk POST, payloads, 4.x quirks) | `mappings/netbox-mapping-guide.md` | reviewed vs NetBox 4.x REST docs | DONE |
| OpenTofu mapping guide (VM/LXC asymmetries, cloud-init/secret adaptation) | `generators/proxmox-opentofu-mapping-guide.md` | reviewed vs bpg/proxmox docs | DONE |
| OpenTofu worked example (1 VM + 1 LXC, secrets as sensitive vars) | `examples/opentofu/proxmox-example.tf` | `tofu` 1.9.0 `init`+`validate` (bpg/proxmox 0.111.1) → SUCCESS | DONE |
| Containerlab rules (kind selection, OPNsense→linux/FRR adaptation, addressing) | `generators/containerlab-rules.md` | reviewed vs containerlab.dev | DONE |
| Containerlab worked example (router-on-a-stick home projection) | `examples/containerlab/generated-topology.clab.yaml` | `yamllint` strict (deploy needs Docker) | DONE |
| Checkov / Trivy guidance (scan generated artifacts, not the model) | folded into `ci/pipeline.md` stage 6 | n/a (guidance) | DONE |
| CI pipeline (9 ordered stages, each tagged verified/described) | `ci/pipeline.md` | stages 1–4,7 run with real tools | DONE |
| yamllint house style | `.yamllint.yml` | `yamllint -s` clean | DONE |
| README (author/validate/generate/integrate, enforcement-layer model, versions) | `README.md` | n/a | DONE |
| CHANGELOG (SemVer + apiVersion policy, v0.1.0 entry) | `CHANGELOG.md` | n/a | DONE |
| Human-readable 20-section report | in-chat response | n/a | DONE |

**Net:** every enumerated hard requirement (§1 "Hard requirements" #1–#13) was produced. The five executable enforcement layers are green: yamllint (strict), JSON Schema (21 docs), Pydantic (`--check`), conftest (`verify` 15/15 + 9/9 per manifest), OpenTofu (`validate`).

---

## 3. Modified (delivered differently than a literal reading of the prompt)

These are intentional deviations. Each lists what changed and why, so the decision can be revisited.

| Area | Literal prompt | What was delivered | Rationale |
| --- | --- | --- | --- |
| Delivery format | "Return everything in one response" with full file contents inline | Built real files; delivered via `present_files` + `infra-schema-v0.1.0.zip`; inlined only key excerpts + the report in chat | A ~5–10k-line pack pasted inline would truncate, violating the no-placeholders constraint. Files preserve fidelity and are directly runnable. The "no placeholders" spirit is better served by tested files than by a wall of untested text. |
| Operating model | (Chris's usual) plan for Claude Code to implement | Claude acted as implementer and produced final artifacts | The prompt explicitly inverted the usual model ("act as implementer"). Flagged in the report; the repo is positioned as a tested v0.1 baseline for Claude Code to iterate against. |
| Research breadth | Cite a broad source set (≈50 referenced) | Targeted verification of _volatile / detail-critical_ sources only (bpg/proxmox fields, Containerlab schema, NetBox 4.x, Conftest/Trivy invocation); stable standards cited from knowledge | Fetching/reading ~50 URLs would exhaust context for little marginal correctness. Effort was spent where being out-of-date actually breaks the deliverable. Prioritized source list is in report §3. |
| Conftest invocation | (implied) run policies over the pack | Documented + enforced **one closed-world unit per `conftest` run** (per manifest), not all manifests pooled | `--combine` pools all passed files into one `input`; the two example manifests intentionally re-declare 5 shared fixtures, so pooling creates duplicate composite keys and `resolve()` errors. Per-unit invocation mirrors the Pydantic per-file default and keeps the layers consistent. |
| `_build/` scripts | (not specified) | `_build/build_schema.py` and `_build/validate_examples.py` shipped as dev helpers, explicitly **not** part of the shipped contract (schema JSON + Pydantic are the contract) | The schema is hand-authored via a Python builder for bracket/comma safety and `$def` reuse; keeping the builder aids reproducibility without implying it's a supported interface. |
| Schema source of truth | (one schema) | Hand-authored `infra.schema.json` is canonical; Pydantic emits a **parallel** schema via `--emit-schema` | The two serve different masters (portable structural truth vs typed runtime + graph). Neither is derived from the other; semantic sync is a documented invariant (any divergence = bug), now enforced by the drift gate `_build/check_drift.py` (see §8, 2026-06-03). |

---

## 4. Not completed / described-not-run

Nothing here is an unmet **hard requirement** from §1 "Hard requirements" — these are either validations that need external systems unavailable in the build environment, or product-completeness items beyond the enumerated deliverables. Tagged by reason.

| Item | Where it stands | Reason not done | Tag |
| --- | --- | --- | --- |
| Containerlab `deploy` of the example topology | Topology yamllint-clean; not deployed | Needs Docker runtime | NEEDS-ENV |
| Batfish snapshot + reachability/failure questions | Described in `ci/pipeline.md` stage 9; FailureScenario kind models the intent | Needs generated/real device configs + Batfish | NEEDS-ENV |
| Checkov scan run | Guidance delivered; not executed | Scans generated artifacts; nothing generated to scan yet | NEEDS-ARTIFACTS |
| Trivy `config` scan run | Guidance delivered; not executed | Scans generated artifacts; nothing generated to scan yet (same as Checkov) | NEEDS-ARTIFACTS |
| `ansible-lint` run + an Ansible inventory/playbook example | Described in CI; no Ansible artifact shipped | Not an enumerated deliverable; no inventory generated | NOT-REQUIRED / FUTURE |
| Live NetBox seed (two-pass POST against a real instance) | Payloads + sequence documented in mapping guide | Needs a NetBox endpoint + token | NEEDS-ENV |
| `tofu plan`/`apply` against real Proxmox | `tofu validate` passes; plan/apply not run | Needs Proxmox API + credentials | NEEDS-ENV |
| Generator **executables** (NetBox seeder, OpenTofu emitter, Ansible inventory, Containerlab emitter, Batfish input) | Mapping **rules** + one worked example per target shipped | Prompt required guides+examples, not executables; executables are the next layer | FUTURE |
| Automated schema↔Pydantic drift gate | Gate built: `_build/check_drift.py` (components C1/C2/C4); see §8 2026-06-03 entry | Built this session | DONE |
| Real fixtures (true domains, addressing, hardware specs) | `.example` domains + representative 10.10.10/24, 10.10.20/24 used | Placeholders pending the real environment values | FUTURE |
| Verbatim original prompt | Reconstructed; moved to `docs/original-prompt.md` (linked from §1) | Attachment text not retained in working context | N/A |

---

## 5. Remaining work to fully satisfy the original prompt

Against the enumerated §1 "Hard requirements" requirements, the pack is **complete**. The only items needed to close the literal prompt to 100% are small and optional:

1. **Delivery-format reconciliation.** If "everything inline in one response" is a hard requirement rather than a default, the files would need to be pasted in full. Recommendation: keep the file-based delivery (fidelity + runnability) and treat this as satisfied. DECISION-NEEDED, low effort.
2. **Source citation completeness.** If a broad (~50) bibliography is required verbatim, expand report §3 from the prioritized list into a full annotated bibliography. Low effort, no code impact.

Everything else in §4 is product hardening (§6 Roadmap), not a gap against the prompt as enumerated.

---

## 6. Roadmap — toward a robust, fully consistent product

Ordered by dependency and leverage. Each phase is independently shippable. Phases are written as objectives for Claude Code to implement against this baseline; specs/ADRs should be authored before each.

### Phase 1 — Lock the contract (prerequisite for generators)

1. **Schema↔Pydantic drift gate.** ✅ **DONE** (`_build/check_drift.py`). Structural-equivalence gate: C1 (valid examples get the same verdict from both validators), C2 (negative corpus rejected by both), C4 (kind-set / required-field / closedness parity). Also included three D6 conformance fixes (PATCH, no `apiVersion` bump) and the negative corpus (`examples/invalid/`). **C3 (polyfactory generative component) deferred** — needs ~6–8 custom providers + `exclude_none=True`; see §8 2026-06-03 entry. Run: `uv run python _build/check_drift.py`.
2. **Real fixtures.** Replace `.example` domains and representative addressing with the true L3D values; move the fixtures into a `live/` tree validated in `--merge` (whole-repo closed-world) mode.
3. **Negative-example corpus as tests.** ✅ **DONE** (folded into #1). `examples/invalid/{structural,graph}/` committed and exercised by the drift gate as regression tests.

_Phase 1 fast-follow (extends #1, non-blocking for Phase 2):_ **C3 generative component** — add `polyfactory`-based generation to the drift gate to catch Pydantic-broader drift on field _values_ (not just shape). Needs ~6–8 custom providers + `exclude_none=True` serialization, pending the explicit-`null`-on-optionals modeling decision (§8 2026-06-03). **Remaining Phase 1 work: #2 (real fixtures → `live/`) + this C3 fast-follow.**

### Phase 2 — Generators (the mapping guides become code)

4. **OpenTofu emitter.** Implement the `proxmox-opentofu-mapping-guide.md` rules as a generator: desired-state → HCL, honoring the VM/LXC field asymmetries and resolving `SecretRef` → `sensitive` variables. Gate output with `tofu validate` in CI; add `tofu plan` against a throwaway Proxmox or a mock when available.
5. **NetBox seeder.** Implement the two-pass seed (independent objects → capture IDs → dependents) with idempotency (lookup-or-create). Add a CI job against a disposable NetBox container; assert round-trip (seed → read back → diff).
6. **Containerlab emitter + deploy smoke test.** Generate topologies from the desired state; run `containerlab deploy` in a Docker-enabled CI runner for a minimal topology to catch kind/endpoint errors.
7. **Ansible inventory generator** (rounds out the target set named in the prompt's intent). Emit inventory groups from zones/clusters and host vars from guest specs; gate with `ansible-lint`.

### Phase 3 — Verification depth

8. **Batfish integration.** Feed generated device configs into Batfish; turn each `FailureScenario` into an automated assertion (expected unavailable / failover / max-outage) so the modeled blast radius is _checked_, not just declared.
9. **Checkov + Trivy in CI.** Run both against the _generated_ OpenTofu/ Containerlab artifacts (not the abstract model); add the custom-Rego checks the guidance describes.
10. **End-to-end pipeline run.** Wire stages 1–9 of `ci/pipeline.md` into an actual GitHub Actions / GitLab CI workflow file and prove a green run on the `live/` fixtures. (The toolchain is now committed — `pyproject.toml`/`uv.lock`/`.mise.toml`/`.python-version` — so the workflow can install it deterministically via `astral-sh/setup-uv` + `jdx/mise-action`; see §8.)

### Phase 4 — Operability & extension

11. **Secret-backend resolution.** Implement the OpenBao path resolution that `SecretRefInline`/`SecretRef` only _describe_ today, so generators can fetch at apply time without ever materializing values into the model or state.
12. **apiVersion maturation.** When the kind set + reference scheme are stable against real generators, promote `v1alpha1` → `v1beta1` per the CHANGELOG policy, with a migration note and a conversion shim.
13. **Additional kinds as needed.** Candidate gaps to evaluate against real use: DNS records, TLS/cert management, VPN/Tailscale ACLs as first-class objects, storage volumes/datasets, and a Site-to-Site link kind for WAN modeling.
14. **Authoring ergonomics.** A `dte`-friendly snippet set or a small `infra new <kind>` scaffolder that emits a valid skeleton per kind, reducing hand-authoring friction.

### Sequencing rationale

Phase 1 must precede Phase 2: generators that build on a contract that can silently drift will produce subtly wrong artifacts. Phase 2 must precede Phase 3: Checkov/Trivy/Batfish all scan _generated_ output, so there must be generators before there is anything to scan or simulate. Phase 4 is operational polish that assumes a working generate→validate loop.

---

## 7. Quick reference — validation commands

```bash
# Toolchain is committed & reproducible (see §8). Run from the repo root.
#   Python validators → uv-managed venv (pyproject.toml + uv.lock).  Reproduce: uv sync
#   conftest / tofu   → mise-pinned (.mise.toml).                    Reproduce: mise install
#   conftest/tofu must be on PATH (shell-activate mise, or prefix each with `mise exec --`).
# Benign: uv prints `VIRTUAL_ENV=/usr ... will be ignored` (this box exports VIRTUAL_ENV
# globally); uv correctly uses the project .venv. Not a failure — ignore it.

uv run yamllint -s -c .yamllint.yml examples/                                                # 1  YAML lint
uv run python _build/validate_examples.py                                                    # 2  JSON Schema
uv run python python/infra_models.py --check examples/kinds/*.yaml examples/manifests/*.yaml # 3  Pydantic + graph
conftest verify -p policies/opa                                                              # 4a policy unit tests → 15/15
conftest test --combine -p policies/opa examples/manifests/site-home.yaml                    # 4b ONE manifest per run
conftest test --combine -p policies/opa examples/manifests/multi-site-failover.yaml          # 4c  (pooling both = dup composite keys)
uv run python _build/check_drift.py                                                          # 4d  drift gate: schema↔Pydantic structural parity (C1/C2/C4)
T=$(mktemp -d) && cp examples/opentofu/*.tf "$T" && ( cd "$T" && tofu init && tofu validate )  # 5  OpenTofu (copy out so init never writes .terraform/ into the generated-artifacts dir)
project-standards validate                                                                   # 6a managed research frontmatter
format-frontmatter --check                                                                   # 6b canonical frontmatter formatting
project-standards reconcile --check --json                                                   # 6c Catalog 5 managed-state fixed point
```

Toolchain validated against (now **pinned & committed** — Python tools in `pyproject.toml`/`uv.lock`, CLIs in `.mise.toml`, interpreter in `.python-version`; see §8): Python 3.12 / pydantic 2.13.4, jsonschema 4.26.0, PyYAML 6.0.3, conftest 0.56.0 (OPA 0.69.0), OpenTofu 1.9.0 (bpg/proxmox 0.111.1), yamllint 1.38.0.

---

## 8. Post-build change log

Append-only record of changes made to the pack _after_ the original build session (§2). Newest first. Schema/policy/example contracts are untouched unless an entry says so.

### 2026-07-29 — Project Standards Catalog 5 adoption

Adopted Project Standards 5.11.0 as a fresh Catalog 5 consumer with exact
`markdown-frontmatter@1.6`. The package retains the repository's declared
`docs/research/**/*.md` scope, installs its managed authoring skill and shared
`@v5` validation caller, and leaves the schema, policies, examples, Python tooling,
and custom session-notes convention unchanged. The existing research report now
has contract-1.1 frontmatter. Package validation, formatter validation, and the
second reconciliation fixed point are clean. The full repository gate was rerun;
isolated OpenTofu initialization resolved bpg/proxmox 0.111.1 and validated the
example successfully, so moving validation-version references were refreshed.

### 2026-06-03 — Drift gate + D6 conformance fixes; Phase 1 #1 done, #3 folded

`_build/check_drift.py` implements the schema↔Pydantic structural-equivalence gate (C1/C2/C4) as a plain exit-0/1 script with no pytest dependency. Three components: **C1** valid documents (`examples/kinds/` + `examples/manifests/`) must get the same pass verdict from both validators; **C2** `examples/invalid/structural/` rejected by both, `examples/invalid/graph/` rejected by Pydantic graph layer; **C4** kind-set / required-field / closedness parity. Run: `uv run python _build/check_drift.py`.

**Negative corpus** `examples/invalid/{structural,graph}/` committed as regression tests — closes Phase 1 #3 (folded into #1).

**D6 conformance fixes** (PATCH; no `apiVersion` bump; no conformant document affected):
- fix-1: `_validate_cidr` tightened to normative CIDR shape (rejects prefix-less / IPv4-mapped forms).
- fix-2: `IpAddress` `$def` in `build_schema.py` gains an enforced `pattern` (was `format`-only); schema regenerated.
- fix-3: `IpAddress`/`Cidr` Pydantic type aliases gain `AfterValidator`s; ~12 fields retyped from bare `str` to the validated aliases (eliminates a class of Pydantic-broader drift that C3 surfaced).

**C3 deferred** (polyfactory generative component): needs ~6–8 custom polyfactory providers for generation artifacts and `exclude_none=True` to produce realistic documents. It is the lens that surfaced the fix-3 drift class. Re-attempt after the explicit-null modeling decision is settled.

**Known boundary — explicit `null` on optional fields:** JSON Schema rejects `field: null` for a non-nullable optional while Pydantic accepts it. Real documents omit unset optionals (never write explicit `null`), so this is outside the gate's tested space and not expected to affect any real document. Tracked, not "fixed."

| Component | Status |
| --- | --- |
| C1 — valid-example parity | DONE |
| C2 — negative corpus + rejection parity | DONE |
| C4 — kind-set / closedness / required-field parity | DONE |
| C3 — polyfactory generative | DEFERRED (fast-follow) |
| D6 fix-1/2/3 | DONE (PATCH) |
| explicit-null boundary | DOCUMENTED (known scope limit) |

### 2026-06-02 — Committed, reproducible validation toolchain (commit `9875018`)

Promoted the toolchain from the ephemeral build environment (binaries in `/home/claude/bin`, Python tools installed ad hoc) into committed, reproducible manifests. **Tooling only — no schema, policy, or example file changed.**

| File | Role |
| --- | --- |
| `pyproject.toml` | Python validators. Non-package (`[tool.uv] package = false`); PEP 735 `[dependency-groups] dev` exact-pins `pydantic==2.13.4`, `jsonschema==4.26.0`, `PyYAML==6.0.3`, `yamllint==1.38.0`. `requires-python = ">=3.12"`. |
| `uv.lock` | Locked transitive resolution (14 packages). |
| `.python-version` | `3.12` — uv provisions managed CPython 3.12.13. |
| `.mise.toml` | Non-Python CLIs: `conftest = "0.56.0"` (bundles OPA 0.69.0), `opentofu = "1.9.0"`. |

- **Reproduce on a fresh machine:** `uv sync` (creates a gitignored `.venv`, installs the `dev` group by default) + `mise install`.
- **Run validation:** §7 — now `uv run …` with no PATH hacks.
- **Versions are identical** to the §2 known-green baseline; they are now pinned _exactly_ (deliberately not track-latest) because the pack was validated against them. Bump intentionally, then re-run stages 1–4.
- **Why two manifests:** the split is a language boundary — uv owns the pure-Python validators (resolved + locked), mise owns the compiled Go CLIs (conftest/opentofu) that pip cannot install. Mirrors workstation conventions §1 (mise) / §2 (uv).
- **Unblocks roadmap §6 Phase 3 #10:** a CI workflow can now install the exact toolchain via `astral-sh/setup-uv` + `jdx/mise-action`.
