# Luminous3D Desired-State Infrastructure Model

Canonical intent layer for a greenfield homelab rebuild. Hand-authored YAML describes the **desired state** of sites, network, Proxmox clusters, guests, services, dependencies, firewall intent, backups, monitoring, and failure scenarios. Downstream generators project that intent into NetBox seed payloads, OpenTofu/Terraform HCL (bpg/proxmox), Ansible inventories, Containerlab topologies, and Batfish inputs.

This is **authoring + validation + projection rules**, not a live runtime. It does not model observed status. NetBox, Proxmox, and the rest are _projection targets_, never the source of truth.

- Schema `$id`: `https://schemas.luminous3d.example/infra/v1alpha1/infra.schema.json`
- `apiVersion`: `infra.luminous3d.example/v1alpha1`
- Dialect: JSON Schema Draft 2020-12
- Status: **tested v0.1.0 baseline** (see CHANGELOG.md and "Validation status" below)

---

## 1. Repo layout

```text
infra-schema/
├── schemas/
│   └── infra.schema.json          # source-of-truth JSON Schema (Draft 2020-12)
├── python/
│   └── infra_models.py            # Pydantic v2 models + graph layer + CLI
├── examples/
│   ├── kinds/                     # one minimal valid example per kind (19)
│   ├── manifests/
│   │   ├── site-home.yaml         # single-site closed world
│   │   └── multi-site-failover.yaml  # multi-site + failover + FailureScenario
│   ├── opentofu/proxmox-example.tf       # generated HCL (1 VM + 1 LXC)
│   └── containerlab/generated-topology.clab.yaml  # generated topology
├── policies/
│   ├── opa/                       # 6 guardrail policies + lib + unit tests
│   └── conftest/                  # conftest.toml + invocation notes
├── mappings/
│   └── netbox-mapping-guide.md    # YAML -> NetBox REST/import payloads
├── generators/
│   ├── proxmox-opentofu-mapping-guide.md  # YAML -> bpg/proxmox HCL
│   └── containerlab-rules.md      # YAML -> Containerlab topology rules
├── ci/
│   └── pipeline.md                # ordered CI stages + commands
├── .yamllint.yml
├── README.md
└── CHANGELOG.md
```

`_build/` (helper scripts that author the schema and run the example harness) is a development convenience, not a shipped interface. The shipped contract is `schemas/infra.schema.json` + `python/infra_models.py`.

---

## 2. The object model in one screen

Envelope (every document): `apiVersion`, `kind`, `metadata{name, namespace?, labels?, annotations?}`, `spec`. Schemas are closed (`additionalProperties: false`); `labels`/`annotations` are the only open extension points.

19 kinds, grouped:

| Group               | Kinds                                                    |
| ------------------- | -------------------------------------------------------- |
| Topology / location | Site, NetworkZone                                        |
| L2/L3 addressing    | Vlan, Prefix, Gateway                                    |
| Physical / DCIM     | Device, Interface                                        |
| Compute             | ProxmoxCluster, Host, VirtualMachine, LxcContainer       |
| Workloads           | Service, ServiceDependency                               |
| Security intent     | FirewallPolicy, AllowedFlow                              |
| Operations          | BackupClass, SecretRef, MonitoringCheck, FailureScenario |

Plus a packaging kind, `InfraManifest` (a Bundle whose `spec.items[]` carries many objects in one file).

### Semantic boundaries (which kind to reach for)

| Distinction | Rule |
| --- | --- |
| Device vs Host | Device = DCIM hardware/asset record. Host = a compute node that runs guests (hypervisor/server role). A box can have both records; they describe different facets. |
| Host vs VirtualMachine/LxcContainer | Host is bare-metal compute; VM/LXC are guests scheduled onto a ProxmoxCluster/Host. |
| Gateway vs Interface | Gateway = an L3 next-hop/routing intent. Interface = a physical/logical port on a Device. |
| FirewallPolicy vs AllowedFlow | FirewallPolicy = posture for a zone pair (incl. `defaultAction`). AllowedFlow = one explicit allow rule (source→destination). |
| Service vs ServiceDependency | Service = a workload exposed on a host/guest. ServiceDependency = a directed edge in the service graph. |

### References

References are **composite keys**, never UIDs or file paths:

```yaml
backupClassRef: { kind: BackupClass, name: backup-critical } # namespace defaults to "default"
```

`{kind, name, namespace?}`. `namespace` defaults to `"default"` consistently across all three enforcement layers. `uid` is reserved/unused for referencing.

### Secrets

Never inline a secret value. Use a `SecretRef` object, or an inline `SecretRefInline` (`{ref}` XOR `{provider, path}` — never `value`). The schema rejects any `value` field on a secret. SecretRef objects are **never** imported to NetBox.

---

## 3. Authoring YAML

Three legal file shapes, all validated the same way:

1. **Single object** — one document, bare envelope. Open-world fragment: structural validation only (its refs may point outside the file).
2. **Bundle** — one `InfraManifest` document with `spec.items[]`. Closed world: graph checks run (unique keys, referential integrity, IP-in-prefix).
3. **Multi-document stream** — several `---`-separated envelopes in one file. Closed world, same as a bundle.

Author rules:

- `metadata.name` is a DNS-style slug (lowercase, `[a-z0-9-]`). The schema enforces the pattern.
- `spec.kind`-specific shape must match the envelope `kind` (schema enforces via per-kind `if/then`).
- Keep one closed world per manifest. A manifest must contain (or re-declare) every object its rules need to resolve. The two example manifests deliberately share 5 fixture objects (`home-fishlake`, `host-k7plus`, `lxc-pihole`, `svc-pihole`, `backup-critical`) for exactly this reason — each is independently complete.

---

## 4. Validate it

Toolchain (versions this baseline was validated against):

| Tool                 | Version         |
| -------------------- | --------------- |
| Python / Pydantic    | 3.12 / 2.13.4   |
| jsonschema           | 4.26.0          |
| PyYAML               | 6.0.3           |
| Conftest / OPA       | 0.56.0 / 0.69.0 |
| OpenTofu             | 1.9.0           |
| bpg/proxmox provider | 0.111.1         |
| yamllint             | 1.38.0          |

### Layer 1 — YAML syntax/style

```bash
yamllint -s .yamllint.yml examples/ policies/
```

### Layer 2 — JSON Schema (structural, per document)

```bash
# repo harness over the example set:
python3 _build/validate_examples.py
# or directly with any 2020-12 validator, e.g. check-jsonschema:
check-jsonschema --schemafile schemas/infra.schema.json examples/kinds/*.yaml
```

### Layer 3 — Pydantic (structural + cross-object graph)

```bash
# per-file default: bundles/streams = closed-world graph checks,
#                   bare single objects = structural only
python3 python/infra_models.py --check examples/kinds/*.yaml examples/manifests/*.yaml

# whole-repo closed world (pool everything into one graph, e.g. a live/ tree):
python3 python/infra_models.py --check --merge live/**/*.yaml

# export the Pydantic-derived JSON Schema (parallel artifact, not the source of truth):
python3 python/infra_models.py --emit-schema
```

### Layer 4 — Guardrail policy (cross-object, OPA/Conftest)

```bash
# unit tests for the policies themselves:
conftest verify -p policies/opa

# evaluate ONE closed world per invocation (--combine pools the passed files):
conftest test --combine -p policies/opa examples/manifests/site-home.yaml
conftest test --combine -p policies/opa examples/manifests/multi-site-failover.yaml
```

> **Invocation rule:** `--combine` makes `input` the array of all passed files. Run conftest **once per closed-world unit** (one manifest, or one `live/` tree). Passing two independent manifests that re-declare shared fixtures pools duplicate composite keys and the `resolve()` function will (correctly) error on the conflicting identity. This mirrors the Pydantic per-file default.

The four layers are ordered by cost and blast radius: syntax → shape → typed graph → policy. Each assumes the previous passed. See `ci/pipeline.md` for the full 9-stage flow including generate/scan/plan stages.

### What each layer enforces (and why it lives there)

| Concern | Layer | Reason |
| --- | --- | --- |
| Envelope shape, enums, patterns, closed objects, per-kind spec | JSON Schema | Single-document structural truth; portable to any validator. |
| Unique composite keys, referential integrity, IP-in-prefix typing | Pydantic | Needs the whole closed world + Python logic JSON Schema can't express. |
| Exposure approval, backup-for-critical, privileged-approval, zone isolation, IP-in-declared-prefix | OPA/Conftest | Org policy that changes independently of the data model; wants unit tests and human-readable deny messages. |
| Generated-artifact correctness (HCL validity, container image posture) | OpenTofu / Checkov / Trivy | These scan emitted artifacts, not the abstract model. |
| Forwarding/reachability, failure impact | Containerlab / Batfish | Require a built topology or parsed device configs. |

---

## 5. Generate artifacts

Generators consume the validated model and emit tool-specific artifacts. This baseline ships the **mapping rules** plus **one worked, tool-validated example per target**; the generator executables themselves are the next implementation layer (directed from the mapping guides).

| Target | Rules | Worked example | Validated with |
| --- | --- | --- | --- |
| NetBox seed/import | `mappings/netbox-mapping-guide.md` | payloads inline in guide | review against NetBox 4.x REST docs |
| OpenTofu (Proxmox) | `generators/proxmox-opentofu-mapping-guide.md` | `examples/opentofu/proxmox-example.tf` | `tofu init/validate` (bpg 0.111.1) |
| Containerlab | `generators/containerlab-rules.md` | `examples/containerlab/generated-topology.clab.yaml` | `yamllint` (deploy needs Docker) |
| Ansible | (described in `ci/pipeline.md` stage 5/8) | — | `ansible-lint` (described) |
| Batfish | (described in `ci/pipeline.md` stage 9) | — | snapshot question pack (described) |

---

## 6. Integration notes per target

**NetBox** — projection target, not authoring format. Two-pass seed: POST independent objects first (sites, VLANs, prefixes, device types), capture their ids, then POST dependents. REST accepts a single object or a list (bulk) on the same endpoint. NetBox has no native NetworkZone, ServiceDependency, firewall, LXC-type, or BackupClass model — those project to custom fields/tags or are dropped. Never import SecretRef. Full payloads and version quirks (Service `parent` GFK, prefix `?within=`) in `mappings/netbox-mapping-guide.md`.

**OpenTofu / bpg/proxmox** — VM↔LXC field asymmetries are the main trap: `on_boot` (VM) vs `start_on_boot` (LXC); `network_device` (VM) vs `network_interface` (LXC). `disk.discard` is the string `"on"`/`"ignore"`. Secrets resolve to `sensitive` variables, never literals. Field-by-field map in `generators/proxmox-opentofu-mapping-guide.md`.

**Ansible** — generate inventory groups from zones/clusters and host vars from guest specs; lint with `ansible-lint`. Described in `ci/pipeline.md`.

**Containerlab** — desired-state projects to `topology.nodes` + `links`. No native OPNsense kind; project the firewall to a `linux`/FRR node and record the adaptation in node labels. Rules in `generators/containerlab-rules.md`.

**Batfish** — consumes generated/real device configs (not the abstract model); answers reachability and failure-impact questions. Pair with FailureScenario objects to assert expected blast radius. Described in `ci/pipeline.md` stage 9.

---

## 7. Validation status of this baseline

Green with real tools in this environment:

- `yamllint -s` over `examples/` and `policies/` — clean.
- JSON Schema validation — 21 example documents pass (19 kinds + 2 manifests).
- Pydantic `--check` — all per-kind and both manifests pass; `--merge` correctly flags cross-manifest duplicate keys.
- `conftest verify` — 15/15 unit tests pass.
- `conftest test --combine` per manifest — 9/9 deny rules satisfied on each.
- `tofu init && tofu validate` on the example HCL — success (provider 0.111.1).

Described but **not executed here** (require Docker, a NetBox/Proxmox endpoint, or device configs): Containerlab deploy, Batfish questions, Checkov, Trivy, ansible-lint, live NetBox seed, `tofu plan` against a real Proxmox API.

---

## 8. Versioning

Schema version travels in `apiVersion` (`v1alpha1`). The repo and schema follow SemVer per CHANGELOG.md. Breaking envelope/spec changes bump the apiVersion track (e.g. `v1alpha1` → `v1beta1`); additive optional fields are minor; clarifications are patch. See CHANGELOG.md for the policy in full.
