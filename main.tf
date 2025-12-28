terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.7"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Create a storage pool if needed
# Create a storage pool if needed
resource "libvirt_pool" "default" {
  name = "default"
  type = "dir"
  target = {
    path = "/var/lib/libvirt/images"
  }
}

# Download Ubuntu cloud image
# Download Ubuntu cloud image
resource "libvirt_volume" "vm_disk" {
  name   = "ubuntu-22.04.qcow2"
  pool   = libvirt_pool.default.name  # Reference the resource
  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64.img"
    }
  }
}


# Cloud-init config
data "template_file" "user_data" {
  template = file("${path.module}/cloud-init.yaml")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = data.template_file.user_data.rendered
  meta_data = yamlencode({
    instance-id    = "vm-01"
    local-hostname = "test-vm"
  })
}

# Define VM
resource "libvirt_domain" "test_vm" {
  name        = "test-vm"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"
  
  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [
      { dev = "hd" },
      { dev = "network" }
    ]
  }
  
  devices = {
    disks = [
      {
        source = {
          file = {
            file = libvirt_volume.vm_disk.path
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        source = {
          file = {
            file = libvirt_cloudinit_disk.commoninit.path
          }
        }
        target = {
          dev = "vdb"
          bus = "virtio"
        }
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]
  }
}

output "vm_ip" {
  value = "Run 'virsh domifaddr test-vm' to get IP address"
}