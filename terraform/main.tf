data "digitalocean_ssh_key" "main" {
  name = var.ssh_key_name
}

data "local_file" "ssh_public_key" {
  filename = "${pathexpand(var.ssh_private_key_path)}.pub"
}

resource "digitalocean_droplet" "openclaw" {
  name     = var.droplet_name
  region   = var.region
  size     = var.size
  image    = "ubuntu-24-04-x64"
  ssh_keys = [data.digitalocean_ssh_key.main.id]
  tags     = ["openclaw"]

  # Wait for the droplet to boot and SSH to become available,
  # then run the ansible playbook.
  provisioner "remote-exec" {
    inline = [
      "echo 'Waiting for cloud-init to finish...'",
      "cloud-init status --wait",

      # Install ansible and git
      "apt-get update -qq",
      "apt-get install -y -qq ansible git > /dev/null 2>&1",

      # Clone openclaw-ansible
      "git clone https://github.com/openclaw/openclaw-ansible.git /root/openclaw-ansible",
      "cd /root/openclaw-ansible && ansible-galaxy collection install -r requirements.yml > /dev/null 2>&1",

      # Run the playbook as root (it creates the openclaw user, installs everything)
      "cd /root/openclaw-ansible && ./run-playbook.sh -e \"openclaw_ssh_keys=['${trimspace(data.local_file.ssh_public_key.content)}']\" -e tailscale_enabled=true",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand(var.ssh_private_key_path))
      host        = self.ipv4_address
      timeout     = "5m"
    }
  }
}

# Cloud firewall: SSH only inbound, all outbound
resource "digitalocean_firewall" "openclaw" {
  name        = "${var.droplet_name}-firewall"
  droplet_ids = [digitalocean_droplet.openclaw.id]

  # SSH from anywhere (Tailscale will be the preferred access method,
  # but SSH needs to be open for initial setup and credential transfer)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Tailscale (UDP for WireGuard)
  inbound_rule {
    protocol         = "udp"
    port_range       = "41641"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # All outbound
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
