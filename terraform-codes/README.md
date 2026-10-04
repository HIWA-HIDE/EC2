# Terraform EC2 Starter Files

Provisions one AWS EC2 server (Ubuntu) with a firewall, then automatically
installs Docker and runs your Dockerized backend — all from code.
Full explanation is in the class guide (Terraform_Guide.docx).

## Files
- `main.tf`               — provider + EC2 instance + security group (firewall) + user_data
- `variables.tf`          — the inputs you can change
- `outputs.tf`            — what Terraform prints after building (IP, ssh command)
- `user_data.sh`          — startup script: adds swap, installs Docker, clones repo, runs app
- `terraform.tfvars.example` — copy to `terraform.tfvars` and fill in your values
- `.gitignore`            — keeps state files and secrets out of Git

## Quick start
```
# 1. one-time: connect AWS CLI (use an IAM user, NOT root)
aws configure

# 2. set your values
copy terraform.tfvars.example terraform.tfvars
#    then edit key_name, my_ip, and repo_url

# 3. build it
terraform init
terraform plan
terraform apply          # type: yes
#    wait ~3 min for Docker to install and the app to start

# 4. test it
#    http://<public_ip>:5000/products

# 5. when finished
terraform destroy        # type: yes
```

## You must provide in terraform.tfvars
- `key_name` — the name of an EXISTING EC2 key pair in your AWS account
- `my_ip`    — your public IP + `/32` (get it from https://ifconfig.me)
- `repo_url` — the PUBLIC git URL of your backend repo

## Security scan (tfsec)
Scan this Terraform code for misconfigurations before building:
```
# simplest: via Docker
docker run --rm -v "${PWD}:/src" aquasec/tfsec /src
```
Or add the tfsec job to your GitHub Actions security workflow (see the guide).

Never commit `terraform.tfvars`, `*.tfstate`, or your `*.pem` key.
