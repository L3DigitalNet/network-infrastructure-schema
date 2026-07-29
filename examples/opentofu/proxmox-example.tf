# =============================================================================
# GENERATED ARTIFACT -- do not hand-edit.
# Source of truth: examples/manifests/site-home.yaml (desired state).
# Generator target: bpg/proxmox OpenTofu provider.
#
# This file is what the OpenTofu generator emits from the desired-state model.
# It is checked into examples/ purely to demonstrate the mapping; in the real
# repo it would live under a generated/ tree and be regenerated, never edited.
#
# Two objects are rendered:
#   * LxcContainer/lxc-pihole   -> proxmox_virtual_environment_container.pihole
#   * VirtualMachine/vm-docker-apps -> proxmox_virtual_environment_vm.docker_apps
#
# SECRETS: the desired-state model references secrets only by SecretRef. The
# generator maps each SecretRef to a *sensitive input variable*; the value is
# injected at plan/apply time from the secret store (OpenBao) or environment,
# never written into HCL. See variables.tf-style block at the bottom.
# =============================================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      # Pin to the minor you have tested. Verify the current version against
      # https://search.opentofu.org/provider/bpg/proxmox/latest before bumping.
      # This file was `tofu validate`-checked against bpg/proxmox 0.111.1.
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token # sensitive; sourced from OpenBao/env
  insecure  = false

  # The provider needs SSH for a few file-upload/import operations; key is also
  # supplied out-of-band rather than embedded.
  ssh {
    agent    = true
    username = "root"
  }
}

# -----------------------------------------------------------------------------
# LxcContainer/lxc-pihole  (Pi-hole + unbound)
# Maps from spec: host.proxmoxNode, vmId, ostemplate, osType, unprivileged,
# features.nesting, cores, memoryMb, swapMb, cpuUnits, rootfs, networkInterfaces,
# sshKeysRef, startOnBoot, tags.
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_container" "pihole" {
  node_name     = "k7plus"
  vm_id         = 120
  unprivileged  = true
  start_on_boot = true
  tags          = ["home", "dns"]

  features {
    nesting = false
  }

  operating_system {
    template_file_id = "local:vztmpl/debian-13-standard_13.0-1_amd64.tar.zst"
    type             = "debian"
  }

  cpu {
    cores = 2
    units = 1024
  }

  memory {
    dedicated = 1024
    swap      = 512
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  network_interface {
    name    = "eth0"
    bridge  = "vmbr0"
    vlan_id = 10
  }

  initialization {
    hostname = "lxc-pihole"

    ip_config {
      ipv4 {
        address = "10.10.10.30/24"
        gateway = "10.10.10.1"
      }
    }

    user_account {
      keys = [var.ssh_authorized_key] # from SecretRef: secret-ssh-authorized
    }
  }
}

# -----------------------------------------------------------------------------
# VirtualMachine/vm-docker-apps  (Docker application host)
# Maps from spec: host.proxmoxNode, cluster, vmId, template (-> clone source),
# osType, cores, memoryMb, agent, startOnBoot, disks, networkInterfaces,
# cloudInit, tags.
# -----------------------------------------------------------------------------
resource "proxmox_virtual_environment_vm" "docker_apps" {
  node_name       = "k7plus"
  vm_id           = 110
  name            = "vm-docker-apps"
  tags            = ["home", "docker"]
  on_boot         = true
  stop_on_destroy = true

  # `template` in the model is a clone source; resolve its VM ID via a variable
  # so the same HCL works across nodes/clusters.
  clone {
    vm_id = var.debian13_template_vmid
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 40
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  initialization {
    datastore_id = "local-lvm"

    ip_config {
      ipv4 {
        address = "10.10.20.10/24"
        gateway = "10.10.20.1"
      }
    }

    user_account {
      username = "chris"
      keys     = [var.ssh_authorized_key] # from SecretRef: secret-ssh-authorized
    }
  }
}

# -----------------------------------------------------------------------------
# Inputs. In a split layout these live in variables.tf; inlined here so the
# example is a single self-contained file. All secret-derived values are marked
# sensitive and have no default -- they MUST be supplied at runtime.
# -----------------------------------------------------------------------------
variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API endpoint, e.g. https://k7plus.luminous3d.example:8006/"
}

variable "proxmox_api_token" {
  type        = string
  description = "Proxmox API token (SecretRef: secret-pve-token), injected from OpenBao."
  sensitive   = true
}

variable "ssh_authorized_key" {
  type        = string
  description = "SSH public key (SecretRef: secret-ssh-authorized)."
  sensitive   = true
}

variable "debian13_template_vmid" {
  type        = number
  description = "VM ID of the debian-13-cloudinit template to clone."
  default     = 9000
}
