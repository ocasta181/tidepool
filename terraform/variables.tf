variable "do_token" {
  description = "DigitalOcean API token (set via TF_VAR_do_token env var)"
  type        = string
  sensitive   = true
}

variable "droplet_name" {
  description = "Name of the Droplet"
  type        = string
  default     = "openclaw"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "sfo3"
}

variable "size" {
  description = "Droplet size slug"
  type        = string
  default     = "s-4vcpu-8gb"
}

variable "ssh_key_name" {
  description = "Name of the SSH key registered with DigitalOcean"
  type        = string
  default     = "MBP"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for provisioner connections"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "openclaw_user" {
  description = "System user for OpenClaw"
  type        = string
  default     = "openclaw"
}
