# ---------------------------------------------------------------------------
# outputs.tf — values Terraform prints after apply
# ---------------------------------------------------------------------------

output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.backend.public_ip
}

output "ssh_command" {
  description = "Ready-to-use SSH command"
  value       = "ssh ubuntu@${aws_instance.backend.public_ip}"
}

output "app_url" {
  description = "Where your app will be reachable"
  value       = "http://${aws_instance.backend.public_ip}:5000"
}
