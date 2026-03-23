#!/bin/bash

set -e  # stop on any error

echo ""

if ! docker info > /dev/null 2>&1; then
  echo "ERROR: Docker Desktop is not running."
  echo "Please open Docker Desktop and try again."
  exit 1
fi
echo "Docker Desktop is running."

echo ""

echo ""
echo "Waiting for node to be Ready..."
bash -c 'until kubectl get nodes 2>/dev/null | grep -q "Ready"; do sleep 3; done'
kubectl get nodes
echo "Node is Ready."

echo ""
if command -v helm > /dev/null 2>&1; then
  echo "Helm already installed. Skipping."
else
  brew install helm
  echo "Helm installed."
fi

echo ""
if helm repo list 2>/dev/null | grep -q "headlamp"; then
  echo "Headlamp repo already added. Skipping."
else
  helm repo add headlamp https://headlamp-k8s.github.io/headlamp/
fi
helm repo update

if helm status headlamp -n headlamp > /dev/null 2>&1; then
  echo "Headlamp already installed. Skipping."
else
  helm install headlamp headlamp/headlamp \
    --namespace headlamp \
    --create-namespace \
    --set service.type=NodePort \
    --set service.nodePort=30080
fi
echo "Headlamp installed."

echo ""
echo "Waiting..."
bash -c 'until kubectl get pods -n headlamp --no-headers 2>/dev/null | grep -q "Running"; do sleep 3; done'
echo "Headlamp is running."

echo ""
echo "Create Admin Token for Headlamp "
kubectl apply -f - <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headlamp-admin
  namespace: headlamp
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: headlamp-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: headlamp-admin
  namespace: headlamp
---
apiVersion: v1
kind: Secret
metadata:
  name: headlamp-admin-token
  namespace: headlamp
  annotations:
    kubernetes.io/service-account.name: headlamp-admin
type: kubernetes.io/service-account-token
YAML

sleep 5
TOKEN=$(kubectl get secret headlamp-admin-token -n headlamp \
  -o jsonpath='{.data.token}' | base64 --decode)
echo "Token created."

echo ""
echo "============================================"
echo "  SETUP COMPLETE!"
echo "============================================"
echo ""
echo "  Headlamp URL  : http://localhost:30080"
echo ""
echo "  Login Token:"
echo "  $TOKEN"
echo ""
echo "  Steps to access Headlamp:"
echo "  1. Open http://localhost:30080 in your browser"
echo "  2. Paste the token above and click Sign In"
echo "============================================"
