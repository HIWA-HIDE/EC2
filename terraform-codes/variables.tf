# ---------------------------------------------------------------------------
# variables.tf — the "knobs". Real values go in terraform.tfvars
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2b"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro" # free-tier eligible on most new accounts
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair in AWS (for SSH access)"
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32 (for SSH access)"
  type        = string
}

variable "repo_url" {
  description = "Git URL of the backend repo to clone & run on boot"
  type        = string
}
