# ---------------------------------------------------------------------------
# main.tf — provider + EC2 instance + security group
# ---------------------------------------------------------------------------

# Tell Terraform we are using AWS, and pin the provider version.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider. Region comes from a variable (see variables.tf).
# Credentials are read automatically from the AWS CLI — never hardcode keys here.
provider "aws" {
  region = var.aws_region
}

# Look up the latest official Ubuntu 22.04 image automatically,
# so we do not hardcode an image ID that differs per region.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (official Ubuntu publisher)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security group = the firewall for the server.
resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow SSH and app traffic"

  # SSH — locked to YOUR ip only (much safer than open to the world).
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # The port your Node/Express app listens on.
  ingress {
    description = "Backend app"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound (so the box can pull Docker images, run apt, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "backend-sg"
  }
}

# The EC2 instance itself.
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name # name of an existing EC2 key pair in AWS
  vpc_security_group_ids = [aws_security_group.backend_sg.id]

  # Startup script: installs Docker and runs the app automatically on first boot.
  # templatefile() injects var.repo_url into the ${repo_url} placeholder.
  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url = var.repo_url
  })

  # user_data only runs on an instance's FIRST boot. This forces Terraform to
  # destroy & recreate the instance whenever the script changes, so it re-runs.
  user_data_replace_on_change = true

  # Require IMDSv2 (token-based metadata requests). Without this, anything
  # that can reach the instance's local metadata endpoint could query it
  # without authentication — tfsec flags this as aws-ec2-enforce-http-token-imds.
  metadata_options {
    http_tokens = "required"
  }

  # Encrypt the root EBS volume at rest. Without this, the disk could be
  # read if it were ever snapshotted/detached — tfsec flags this as
  # aws-ec2-enable-at-rest-encryption. Note: this can only be set at
  # creation time, so changing it forces a destroy + recreate.
  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "backend-server"
  }
}
