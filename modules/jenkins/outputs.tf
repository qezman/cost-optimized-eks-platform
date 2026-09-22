output "jenkins_public_ip" {
  description = "Public IP of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_public_dns" {
  description = "Public DNS of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.public_dns
}

output "jenkins_role_arn" {
  description = "ARN of the Jenkins EC2 instance's IAM role"
  value       = aws_iam_role.jenkins.arn
}

output "jenkins_key_fingerprint" {
  description = "Fingerprint of the SSH key pair attached to the Jenkins instance"
  value       = aws_key_pair.jenkins.fingerprint
}
