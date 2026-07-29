# Changelog

All notable changes to the Luminous3D desired-state infrastructure model are recorded here. Format follows Keep a Changelog; the project follows Semantic Versioning.

## Versioning policy

Two coupled version tracks:

1. **`apiVersion`** (in every YAML document, e.g. `infra.luminous3d.example/v1alpha1`) — the stability contract of the object model. Maturity ladder mirrors Kubernetes: `vNalpha1` → `vNbeta1` → `vN`.
2. **Repo/schema SemVer** (`MAJOR.MINOR.PATCH`, in this file and any release tag) — the version of the schema pack as shipped.

Change classification:

| Change | apiVersion impact | SemVer impact |
| --- | --- | --- |
| Remove/rename an envelope or spec field; tighten an existing constraint so previously-valid docs now fail; change a reference scheme | bump apiVersion track (e.g. `v1alpha1`→`v1beta1`); provide migration notes | MAJOR |
| Add a new kind; add an optional field; add a new policy that only warns | same apiVersion | MINOR |
| Add a `deny` policy that rejects previously-accepted documents | same apiVersion (data shape unchanged) but it is a behavior break | MAJOR (policy layer) |
| Loosen a constraint (accept more) | same apiVersion | MINOR |
| Docs, comments, example fixes, non-normative clarifications | same apiVersion | PATCH |

Rules of thumb:

- While on an `alpha` apiVersion, breaking changes are permitted between MINOR releases but must still be listed under a "Changed (breaking)" heading here.
- Promote `alpha` → `beta` only once the kind set and reference scheme are considered stable for external generators to build against.
- The hand-authored `schemas/infra.schema.json` is the normative artifact. The Pydantic-derived schema (`infra_models.py --emit-schema`) is a parallel validator and is allowed to differ in non-semantic presentation (descriptions, `$defs` naming); any _semantic_ divergence is a bug, not a version event.

## [Unreleased]

### Added

- **Project Standards Catalog 5 control plane** at release 5.11.0 with exact
  `markdown-frontmatter@1.6` adoption. The governed corpus remains narrowly scoped to
  `docs/research/**/*.md`; reconciliation installs the shared authoring skill and the
  `@v5` reusable validation workflow without changing the schema, policies, examples,
  or Python toolchain.
- **Schema↔Pydantic drift gate** (`_build/check_drift.py`): a plain-script CI gate (exit 0/1, no pytest) that fails when `schemas/infra.schema.json` (normative) and `python/infra_models.py` (Pydantic) would accept or reject different documents. Three components: **C1** — all 21 valid documents (`examples/kinds/` + `examples/manifests/`) must receive the same pass verdict from both validators; **C2** — an invalid corpus under `examples/invalid/structural/` must be rejected by both, and `examples/invalid/graph/` documents must be rejected by the Pydantic graph layer; **C4** — kind-set, required-field, and closedness parity. Run: `uv run python _build/check_drift.py`. The JSON Schema validator runs with no `format_checker` (format is annotation-only repo-wide). Closes roadmap §6 Phase 1 #1.
- **Negative-example corpus** (`examples/invalid/{structural,graph}/`): committed set of intentionally invalid documents exercised by the drift gate as regression tests. Closes roadmap §6 Phase 1 #3 (folded into the drift gate work).

### Fixed

- **D6 — Schema↔Pydantic conformance fixes** (PATCH; classified as bug, not a version event; no document valid under _both_ validators was affected; no `apiVersion` bump):
  - **fix-1:** `_validate_cidr` in `python/infra_models.py` tightened to the normative CIDR shape, rejecting prefix-less and IPv4-mapped forms that the schema already rejected.
  - **fix-2:** the `IpAddress` `$def` in `_build/build_schema.py` gained an enforced `pattern` (was `format`-only, i.e. annotation-only/unenforced); schema regenerated.
  - **fix-3:** the `IpAddress`/`Cidr` Pydantic type aliases now carry `AfterValidator`s, and ~12 fields that were bare `str` (e.g. `PrefixSpec.gateway`, `GatewaySpec.address`, `DeviceSpec.managementIp`, `HostSpec.managementIp`, `ServiceSpec.vip`, `InterfaceSpec.addresses`, `DhcpRange.start`/`end`, `Vrrp.virtualAddress`, `FlowEndpoint.cidr`, `IpConfig.gateway`) were retyped to the validated aliases, eliminating a class of "Pydantic-broader" drift.

### Known limitations / deferred

- **C3 (polyfactory generative component) — deferred.** Property-based / generative testing via polyfactory needs ~6–8 custom providers for generation artifacts and must dump with `exclude_none=True` to produce realistic documents. C3 is the lens that surfaced the fix-3 drift class; it is a documented fast-follow, not a current deliverable.
- **Explicit `null` on optional fields** — JSON Schema rejects `field: null` for a non-nullable optional while Pydantic accepts it. Real documents always omit unset optionals (never write explicit `null`), so this divergence is outside the gate's tested space and is not expected to affect any real document. Tracked as a known boundary.

## [0.1.0] — 2026-06-02

Initial tested baseline. `apiVersion: infra.luminous3d.example/v1alpha1`.

### Added

- **JSON Schema** (`schemas/infra.schema.json`, Draft 2020-12): shared envelope (`apiVersion`/`kind`/`metadata`/`spec`), 19 object kinds plus the `InfraManifest` bundle, closed objects throughout, per-kind `if/then` discrimination, reusable `$defs` (ObjectRef, SecretRefInline, ExposureDecision, enums). Root `oneOf[Object, Bundle]`.
- **Pydantic v2 models** (`python/infra_models.py`): strict base (`extra=forbid`), one `*Spec` per kind, discriminated `AnyObject` union, `InfraManifest`, a graph layer (`check_manifest`: unique composite keys, referential integrity, IP-in-prefix), and a CLI (`--check`, `--merge`, `--emit-schema`).
- **Examples**: one minimal valid document per kind (19 files); two manifests — `site-home.yaml` (single-site closed world) and `multi-site-failover.yaml` (multi-site + failover + FailureScenario).
- **Guardrail policies** (`policies/opa/`): exposure (public service needs an approved ExposureDecision), backup (critical service needs a resolvable BackupClass with a restore target), privileged (privileged LXC needs an approval annotation), zone_isolation (management must not join guest/IoT), ip_prefix (guest IPv4 within a declared Prefix); shared `lib/objects.rego`; 15 unit tests in `policy_test.rego`; `conftest/` invocation notes.
- **Mappings & generator rules**: NetBox seed/import guide (two-pass seed, bulk POST, concrete payloads, version quirks); bpg/proxmox HCL mapping guide (VM/LXC field asymmetries, cloud-init/secret adaptation points); Containerlab topology rules.
- **Worked generated examples**: `examples/opentofu/proxmox-example.tf` (1 VM + 1 LXC); `examples/containerlab/generated-topology.clab.yaml` (router-on-a-stick home projection).
- **CI** (`ci/pipeline.md`): 9 ordered stages with commands, each tagged `[verified]` or `[described]`; Checkov/Trivy scope guidance (they scan generated artifacts, not the abstract model).
- **README** and this **CHANGELOG**; `.yamllint.yml` house style.

### Validation

Verified in-environment: `yamllint -s` (clean); JSON Schema (21 docs pass); Pydantic `--check` (all kinds + both manifests pass; `--merge` flags cross-manifest duplicate keys as designed); `conftest verify` (15/15); `conftest test --combine` per manifest (9/9 each); `tofu init && validate` on the example HCL (success, bpg/proxmox 0.108.0).

Described, not executed here (need Docker, live endpoints, or device configs): Containerlab deploy, Batfish, Checkov, Trivy, ansible-lint, live NetBox seed, `tofu plan` against a real Proxmox API.

### Known limitations

- Generator executables are not yet implemented; only mapping rules + one worked example per target ship in this baseline.
- NetBox cannot represent NetworkZone, ServiceDependency, firewall intent, an LXC guest type, or BackupClass natively; these project to custom fields/tags/labels or are intentionally dropped.
- Containerlab has no native OPNsense kind; the firewall projects to a `linux`/FRR node with the adaptation recorded in labels.
- Conftest must be invoked once per closed-world unit; pooling independent manifests that re-declare shared fixtures is unsupported by design.

[Unreleased]: https://l3digital.example/infra-schema/compare/v0.1.0...HEAD
[0.1.0]: https://l3digital.example/infra-schema/releases/tag/v0.1.0
