#!/bin/bash
# ---------------------------------------------------------------------------
# user_data.sh — runs ONCE, automatically, when the EC2 instance first boots.
# AWS executes this as root. Output is logged to:
#   /var/log/cloud-init-output.log   (check it to debug)
# ---------------------------------------------------------------------------
set -e

# 0) Add 2 GB swap. A t3.micro has only ~1 GB RAM and MySQL 8 needs breathing
#    room, or it gets killed. The fstab line keeps the swap after a reboot.
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

# 1) Install git and Docker (the official script also installs the compose plugin)
apt-get update -y
apt-get install -y git
curl -fsSL https://get.docker.com | sh

# 2) Let the normal 'ubuntu' user run docker without sudo
usermod -aG docker ubuntu

# 3) Clone your backend repo and start it with docker compose
cd /home/ubuntu
git clone ${repo_url} app
cd app
docker compose up -d --build

echo "user_data finished: app should be running on port 5000"
