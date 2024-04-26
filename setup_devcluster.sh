#!/bin/bash

# Function to check if a command is available
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Install k3d if not already installed
if ! command_exists k3d; then
  echo "k3d not found. Installing..."
  curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
  echo "k3d installed successfully."
fi

# Check if kubectl is installed
if ! command_exists kubectl; then
  echo "kubectl not found. Installing..."
  # Install kubectl
  curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  sudo mv ./kubectl /usr/local/bin/kubectl
  echo "kubectl installed successfully."
fi

# Check if helm is installed
if ! command_exists helm; then
  echo "helm not found. Installing..."
  # Install helm
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
  chmod +x get_helm.sh
  ./get_helm.sh
  rm get_helm.sh
  echo "helm installed successfully."
fi

# Set variables
KUBECONFIG_DIR="$HOME/.kube"
K3D_KUBECONFIG="$KUBECONFIG_DIR/k3dconfig"

# Create k3dcluster kubeconfig file if it doesn't exist
if [ ! -f "$K3D_KUBECONFIG" ]; then
  echo "Creating k3dcluster kubeconfig file..."
  touch "$K3D_KUBECONFIG"
  echo "k3dconfig kubeconfig file created successfully."
fi

# Set custom KUBECONFIG path
export KUBECONFIG="$K3D_KUBECONFIG"

# Create k3d cluster
echo "Creating k3d-cluster..."
k3d cluster create --api-port 6550 -p "8080:80@loadbalancer" --agents 2 --kubeconfig-switch-context

# Install Argo CD
echo "Installing and configuring ArgoCD..."
helm install argo-cd argo-cd --repo https://argoproj.github.io/argo-helm -n argocd --create-namespace --set configs.params."server\.insecure"=true --set configs.params."server\.rootpath"=/argocd --wait

# Create ingress for Argo CD
kubectl create ingress argocd --class=traefik --rule=/argocd*=argo-cd-argocd-server:80 --annotation ingress.kubernetes.io/ssl-redirect=false -n argocd

# Get Argo CD initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o go-template='{{printf "\nurl: http://localhost:8080/argocd\nuser: admin\npass: %s\n" (.data.password|base64decode)}}'