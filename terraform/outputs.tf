output "droplet_ip" {
  description = "Public IP of the OpenClaw Droplet"
  value       = digitalocean_droplet.openclaw.ipv4_address
}

output "droplet_id" {
  description = "Droplet ID (for snapshots, backups)"
  value       = digitalocean_droplet.openclaw.id
}

output "ssh_command" {
  description = "SSH into the Droplet as the openclaw user"
  value       = "ssh openclaw@${digitalocean_droplet.openclaw.ipv4_address}"
}

output "tunnel_command" {
  description = "SSH tunnel for dashboard access"
  value       = "ssh -L 18789:127.0.0.1:18789 openclaw@${digitalocean_droplet.openclaw.ipv4_address}"
}

output "dashboard_url" {
  description = "Dashboard URL (after SSH tunnel is active)"
  value       = "http://127.0.0.1:18789"
}
