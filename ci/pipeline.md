# CI pipeline

The pipeline validates desired-state intent from cheapest/fastest to most
expensive, and only generates downstream artifacts once intent is proven sound.
Stages 1–6 gate every change; stages 7–9 run where credentials/runners allow.

Stages marked **[verified]** were executed against this repo's examples with the
named tool during authoring; stages marked **[described]** specify the command
and expected I/O but depend on tooling/credentials not present in the authoring
sandbox.

## Stage order and rationale

The ordering is deliberate: structural checks (lint, schema, types) fail fast
and cheap; cross-object policy runs once structure is trustworthy; security
scanners and `tofu`/`ansible`/`batfish` run last because they are slower and/or
need generated artifacts or credentials.

| # | Stage | Tool | Gates on |
|---|-------|------|----------|
| 1 | YAML syntax/style | yamllint | malformed or off-style YAML |
| 2 | Schema validation | jsonschema (Draft 2020-12) | envelope/spec shape, closedness |
| 3 | Structural + graph model | Pydantic v2 (`infra_models.py`) | types, cross-field rules, references, IP-in-prefix |
| 4 | Guardrail policy | Conftest/OPA | governance + cross-object rules |
| 4b | Contract drift gate | `check_drift.py` | structural equivalence of JSON Schema ↔ Pydantic |
| 5 | Generate artifacts | generators | (produces NetBox/HCL/clab/ansible) |
| 6 | IaC security scan | Checkov, Trivy | misconfig in _generated_ HCL |
| 7 | OpenTofu | `tofu validate` / `plan` | provider-schema correctness; intended change |
| 8 | Ansible lint | ansible-lint | generated playbook/inventory hygiene |
| 9 | Network analysis | Containerlab + Batfish | reachability/forwarding intent |

## Stage 1 — YAML syntax/style **[verified: yamllint 1.38.0]**

```bash
yamllint -s -c .yamllint.yml examples/ live/
```
Fails on malformed YAML or house-style violations. `-s` (strict) makes warnings
fail too.

## Stage 2 — JSON Schema validation **[verified: jsonschema, Draft 2020-12]**

```bash
python3 _build/validate_examples.py        # validates examples/kinds + manifests
# or directly:
python3 - <<'PY'
import json, yaml, sys
from jsonschema import Draft202012Validator
schema = json.load(open("schemas/infra.schema.json"))
Draft202012Validator.check_schema(schema)
v = Draft202012Validator(schema)
for doc in yaml.safe_load_all(open("live/site-home.yaml")):
    if doc: v.validate(doc)
PY
```
Validates the envelope and each `spec` against the closed per-kind schema.
Catches unknown keys, bad enums, wrong types, and `kind`/`spec` mismatches.
Generated artifacts under `examples/` (clab, HCL) are intentionally excluded —
they are not desired-state objects.

## Stage 3 — Pydantic structural + graph checks **[verified: pydantic 2.13.4]**

```bash
# per-file: bundles/streams are closed-world, single objects are fragments
python3 python/infra_models.py --check live/*.yaml
# whole-repo closed-world graph (uniqueness, referential integrity, IP-in-prefix)
python3 python/infra_models.py --merge --check $(find live -name '*.yaml')
```
The model layer enforces what JSON Schema cannot: cross-field invariants
(public exposure needs approval; SecretRef is ref-XOR-inline), composite-key
uniqueness, referential integrity of every `ObjectRef`, and that static guest
IPs fall inside a declared `Prefix`. Use `--merge` for the canonical `live/`
tree; per-file (default) for fragment examples and unit fixtures.

## Stage 4 — Guardrail policy **[verified: conftest 0.56.0 / OPA 0.69.0]**

```bash
conftest test --combine -p policies/opa $(find live -name '*.yaml')
conftest verify -p policies/opa            # policy unit tests
```
`--combine` is mandatory (cross-object rules need the whole set as one `input`).
Enforces the five required policies (public-exposure approval, critical-service
backup+restore, privileged-container approval, management isolation,
IP-in-prefix). See `policies/conftest/README.md`.

## Stage 4b — Contract drift gate **[verified: check_drift.py]**

```bash
uv run python _build/check_drift.py
```
Fails (exit 1) when `schemas/infra.schema.json` and `python/infra_models.py`
would accept or reject different documents. Three components:

- **C1** — every document under `examples/kinds/` and `examples/manifests/`
  must receive the same pass verdict from both the JSON Schema validator and
  Pydantic. Detects "schema-broader" or "Pydantic-broader" drift on the
  existing example corpus.
- **C2** — documents under `examples/invalid/structural/` must be rejected by
  both validators; documents under `examples/invalid/graph/` must be rejected
  by the Pydantic graph layer. Keeps the negative corpus honest.
- **C4** — kind-set, required-field, and closedness parity between the two
  validators. Catches a new kind added to one side only, or a field made
  optional in one but not the other.

**Out of scope for this gate** (handled by stages 3 and 4, or deferred):

- Cross-field graph checks (IP-in-prefix, referential integrity, composite-key
  uniqueness) — owned by the Pydantic graph layer (stage 3) and OPA policies
  (stage 4).
- Explicit `null` on optional fields — JSON Schema rejects `field: null` for a
  non-nullable optional while Pydantic accepts it; real documents never write
  explicit `null`, so this is outside the gate's tested space.
- C3 generative (polyfactory property-based testing) — deferred; needs ~6–8
  custom providers and `exclude_none=True` serialization.

The JSON Schema validator runs with no `format_checker` (format is
annotation-only repo-wide). Expected output: `OK -- schema and Pydantic agree
(19 kinds, 19 examples).`

## Stage 5 — Generate artifacts **[described]**

Run the generators to produce the downstream targets:
```bash
infra-gen netbox  live/  > out/netbox-seed.json
infra-gen tofu    live/  -o out/opentofu/
infra-gen clab    live/  -o out/containerlab/
infra-gen ansible live/  -o out/ansible/
```
(`infra-gen` is the project's generator entry point; the mapping rules it
implements are in `mappings/` and `generators/`.) Artifacts are written under
`out/` and never hand-edited.

## Stage 6 — IaC security scan (Checkov, Trivy) **[described]**

**Key point: Checkov and Trivy scan *generated artifacts*, not the abstract
desired-state model.** The YAML model is platform-neutral intent and has no
notion of, say, an open security group or an unencrypted disk — there is nothing
for an IaC scanner to match. Once the generator emits Terraform/HCL (and
optionally Docker Compose for containerized services), those concrete artifacts
are exactly what Checkov and Trivy understand.

What they realistically catch on the generated HCL/compose:
- Checkov: provider-aware misconfig checks and your custom YAML/Python policies
  (e.g. "VMs must set an agent", "no privileged compose service").
- Trivy `config`: IaC misconfiguration scanning over the same artifacts, plus
  custom Rego checks (`--config-check`), and secret scanning to catch a secret
  that leaked into a generated file.

```bash
checkov -d out/opentofu/ --quiet
trivy config out/opentofu/
trivy config --misconfig-scanners rego --config-check policies/trivy/ out/opentofu/
trivy fs --scanners secret out/        # belt-and-suspenders: no secrets in artifacts
```
Because secrets are modeled only as `SecretRef` and rendered as sensitive
variables, Trivy's secret scan over `out/` should always be clean; a hit means
the generator regressed.

This repo's own guardrails (Stage 4) cover the *intent* layer; Checkov/Trivy
cover the *generated* layer. They are complementary, not redundant.

## Stage 7 — OpenTofu **[verified: tofu 1.9.0 + bpg/proxmox 0.111.1 for `validate`]**

```bash
cd out/opentofu
tofu init -input=false
tofu validate                              # offline: HCL + provider schema
tofu plan -input=false -out=plan.tfplan    # needs PVE creds + reachability
```
`tofu validate` runs anywhere the provider can be downloaded and catches the
field-name traps in `generators/proxmox-opentofu-mapping-guide.md`. `tofu plan`
runs only on a runner with Proxmox credentials and a reachable endpoint;
publish `plan.tfplan` (and a `tofu show -json` rendering) as a build artifact.

## Stage 8 — ansible-lint **[described]**

```bash
ansible-lint out/ansible/
```
Lints the generated inventories/playbooks for syntax and best-practice issues.
Expected input: generated `inventory.yml` + any role/playbook stubs; expected
output: zero violations (or a reviewed `.ansible-lint` ignore set).

## Stage 9 — Containerlab + Batfish **[described]**

Containerlab structure check (no container standup):
```bash
containerlab inspect --topo out/containerlab/generated-topology.clab.yaml
```
Full deploy + Batfish reachability (Docker-capable runner):
```bash
containerlab deploy --topo out/containerlab/generated-topology.clab.yaml
# Batfish: load rendered device configs, then assert reachability intent
python3 tests/batfish/reachability.py
```
**Expected inputs:** rendered router/firewall configs (the `startup-config`
files referenced by the topology) plus the topology itself. **Expected
outputs/assertions** (Batfish question notebooks):
- forwarding analysis confirms each `AllowedFlow` is permitted end-to-end;
- the management-isolation invariant holds — `iot`/`guest` endpoints have **no**
  forwarding path to the `management` endpoint (this is the emergent-reachability
  backstop that the static Stage-4 policy cannot fully prove);
- failure-impact analysis replays each `FailureScenario` (e.g. `host-k7plus`
  down) and confirms the documented failover path still reaches critical
  services.

## Artifacts published by a green run

- `out/netbox-seed.json` — NetBox bulk-create payloads
- `out/opentofu/` + `plan.tfplan` — HCL and the reviewed plan
- `out/ansible/` — inventories/vars
- `out/containerlab/` — topology (+ rendered configs)
- Batfish assertion report

## Minimal GitHub Actions / GitLab CI shape

```yaml
# Conceptual; one job per gating stage, fail-fast in order.
stages: [lint, schema, model, policy, generate, scan, tofu, ansible, netsim]
# lint   -> yamllint
# schema -> jsonschema
# model  -> python infra_models.py --merge --check
# policy -> conftest test --combine + conftest verify
# generate/scan/tofu/ansible/netsim as above; netsim needs a Docker runner.
```
