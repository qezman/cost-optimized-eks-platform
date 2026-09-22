#!/bin/bash
set -e
set -o pipefail
exec > /var/log/user-data.log 2>&1

# This script bootstraps the Jenkins EC2 host with the base toolchain needed for
# infrastructure automation: Java, Jenkins itself, Docker, Terraform, kubectl,
# Helm, and the AWS CLI

# Retries a flaky command (common with package installs and downloads) with backoff
retry() {
  local n=0
  local max=5
  local delay=5
  until [ "$n" -ge "$max" ]; do
    "$@" && return 0
    n=$((n + 1))
    echo "Attempt $n/$max failed, retrying in ${delay}s..."
    sleep "$delay"
  done
  echo "Command failed after $max attempts: $*"
  return 1
}

# Update the base OS image before installing tools
echo "Updating system..."
retry apt-get update -y
apt-get upgrade -y

# Jenkins requires Java to run
echo "Installing Java..."
retry apt-get install -y fontconfig openjdk-21-jre

# Install the Jenkins package from the official Debian repository
echo "Installing Jenkins..."
retry curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /usr/share/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc]" \
  "https://pkg.jenkins.io/debian-stable binary/" | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
retry apt-get update -y
retry apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# Install Docker so Jenkins can build and run container-based workloads
echo "Installing Docker..."
retry apt-get install -y ca-certificates curl gnupg unzip
install -m 0755 -d /etc/apt/keyrings
retry curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
retry apt-get update -y
retry apt-get install -y docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
usermod -aG docker jenkins

# Install Terraform for IaC automation
echo "Installing Terraform..."
retry bash -c 'wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg'
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  tee /etc/apt/sources.list.d/hashicorp.list
retry apt-get update -y
retry apt-get install -y terraform

# Install kubectl to interact with the Kubernetes cluster
echo "Installing kubectl..."
retry curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl

# Install Helm for chart-based deployment management
echo "Installing Helm..."
retry curl -fsSL -o /tmp/get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 /tmp/get_helm.sh
/tmp/get_helm.sh

# Install the AWS CLI so Jenkins can authenticate and manage AWS resources
echo "Installing AWS CLI v2..."
retry curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -o /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update

# Restart Jenkins to ensure the service picks up the final runtime environment
systemctl restart jenkins
echo "Setup complete."
