# OpenTofu / Proxmox mapping guide (bpg/proxmox provider)

This guide documents how `VirtualMachine` and `LxcContainer` desired-state
objects map to the [bpg/proxmox](https://search.opentofu.org/provider/bpg/proxmox/latest)
OpenTofu provider, and where Proxmox/cloud-init specifics require adaptation.
The companion artifact `examples/opentofu/proxmox-example.tf` is the rendered
output for `lxc-pihole` and `vm-docker-apps`; it has been `tofu validate`-checked
against bpg/proxmox **0.111.1**.

Legacy note: older guidance often references the **Telmate** provider. Use
**bpg/proxmox**; Telmate is mentioned only as historical context and its
resource/attribute names do not match what is below.

## Why a generator, not hand-written HCL

The desired-state model is platform-neutral intent ("this LXC has 2 cores, this
IP, this template"). The generator renders provider-specific HCL from it so the
intent stays in one place and the HCL is reproducible. The rendered file is
treated as a build artifact: regenerate, never hand-edit.

## LxcContainer → `proxmox_virtual_environment_container`

| Desired-state field | Provider attribute | Notes |
|---------------------|--------------------|-------|
| `spec.proxmoxNode` | `node_name` | Target PVE node. |
| `spec.vmId` | `vm_id` | |
| `spec.unprivileged` | `unprivileged` | Drives policy 3. |
| `spec.features.nesting` | `features { nesting }` | |
| `spec.ostemplate` | `operating_system { template_file_id }` | |
| `spec.osType` | `operating_system { type }` | e.g. `debian`. |
| `spec.cores` | `cpu { cores }` | |
| `spec.cpuUnits` | `cpu { units }` | |
| `spec.memoryMb` | `memory { dedicated }` | MB. |
| `spec.swapMb` | `memory { swap }` | MB. |
| `spec.rootfs.datastore` / `.sizeGb` | `disk { datastore_id, size }` | `size` is in GB (integer). |
| `spec.networkInterfaces[]` | `network_interface { name, bridge, vlan_id }` | One block per NIC. |
| `spec.networkInterfaces[].ipv4` | `initialization { ip_config { ipv4 { address, gateway } } }` | |
| (hostname from `metadata.name`) | `initialization { hostname }` | |
| `spec.sshKeysRef` | `initialization { user_account { keys = [var…] } }` | SecretRef → sensitive variable. |
| `spec.startOnBoot` | `start_on_boot` | **Container** uses `start_on_boot`. |
| `spec.tags` | `tags` | |
| `spec.mountPoints[]` | `mount_point { volume, path, size, … }` | Optional; one block each. |

## VirtualMachine → `proxmox_virtual_environment_vm`

| Desired-state field | Provider attribute | Notes |
|---------------------|--------------------|-------|
| `spec.proxmoxNode` | `node_name` | |
| `spec.vmId` | `vm_id` | |
| `metadata.name` | `name` | |
| `spec.template` | `clone { vm_id, full }` | Template **name** resolves to a template VM ID via a variable/lookup; bpg clones by `vm_id`. |
| `spec.osType` | `operating_system { type }` *(optional)* | The example relies on the cloned template's OS; set explicitly if not cloning. |
| `spec.cores` | `cpu { cores }` | `cpu { type = "host" }` recommended for homelab. |
| `spec.memoryMb` | `memory { dedicated }` | MB. |
| `spec.agent` | `agent { enabled }` | |
| `spec.disks[]` | `disk { datastore_id, interface, size, iothread, discard, file_format }` | `size` GB; `discard` is `"on"`/`"ignore"` (string), not bool. |
| `spec.networkInterfaces[]` | `network_device { bridge, model, vlan_id }` | Note: VM uses `network_device`, container uses `network_interface`. |
| `spec.networkInterfaces[].ipv4` | `initialization { ip_config { ipv4 { address, gateway } } }` | |
| `spec.cloudInit.username` | `initialization { user_account { username } }` | |
| `spec.cloudInit.sshKeysRef` | `initialization { user_account { keys = [var…] } }` | SecretRef → sensitive variable. |
| `spec.cloudInit.datastore` | `initialization { datastore_id }` | Where the cloud-init drive lives. |
| `spec.startOnBoot` | `on_boot` | **VM** uses `on_boot` (asymmetry vs the container's `start_on_boot`). |
| `spec.tags` | `tags` | |

## Asymmetries that cause real errors

These are the field-name traps verified against the provider schema:

- **`on_boot` (VM) vs `start_on_boot` (container).** Using the wrong one fails
  validation.
- **`network_device` (VM) vs `network_interface` (container).**
- **`disk.discard` is a string** (`"on"`/`"ignore"`), and `disk.size` is an
  integer count of GB. `file_format` (e.g. `"raw"`) is set on the disk block.
- **CPU/memory are nested blocks** (`cpu { cores }`, `memory { dedicated }`),
  not top-level scalars.
- VM provisioning that clones uses a **`clone` block keyed by `vm_id`**; there
  is no "template by name" — resolve the name to an ID in the generator.

## Cloud-init specifics (adaptation points)

- bpg supports both per-attribute cloud-init (`initialization { user_account,
  ip_config, dns }`) and a `user_data_file_id` pointing at a snippet on a
  datastore that has the **`snippets`** content type enabled. The default
  generator uses the structured `initialization` block; switch to
  `user_data_file_id` when you need full cloud-init `#cloud-config` control.
- `ip_config` with `ipv4 { address = "dhcp" }` is valid and bypasses the
  IP-in-prefix policy (the policy ignores `dhcp`).
- Datastore IDs (`local-lvm`, `local`) are environment-specific; they are passed
  through verbatim from the model and must match your PVE storage names.
- The cloud-init template must already exist on the node (the `clone` source);
  building templates is out of scope for this generator.

## Secrets

No secret value ever appears in HCL. Each `SecretRef` maps to a **sensitive
input variable** with no default (`proxmox_api_token` ← `secret-pve-token`,
`ssh_authorized_key` ← `secret-ssh-authorized`). Values are injected at
plan/apply time from OpenBao or the environment. This keeps the generated HCL
safe to commit.

## Validate / plan in CI

```bash
cd generated/opentofu
tofu init -input=false
tofu validate
tofu plan -input=false -out=plan.tfplan   # needs provider creds + reachable PVE
```

`tofu validate` checks HCL + provider schema offline (no PVE needed) and is the
gate that catches the field-name traps above. `tofu plan` additionally needs
credentials and a reachable Proxmox endpoint, so it runs only where those are
available (see `ci/pipeline.md`).
