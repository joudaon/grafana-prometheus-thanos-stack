#!/bin/bash

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# 🎯 Initial configuration
# ─────────────────────────────────────────────────────────────
CLUSTER_NAME="master"
ARGOCD_VERSION="7.8.16"
ARGOCD_DOMAIN="argocd.myorg.com"
ARGOCD_PORT="8443"
GRAFANA_DOMAIN="grafana.local"
QUERIER_THANOS_DOMAIN="querier-thanos.local"
MINIO_DOMAIN="minio-console.local"
CREDENTIALS_FILE="credentials.txt"

# ─────────────────────────────────────────────────────────────
# 🧹 Delete existing cluster (if any)
# ─────────────────────────────────────────────────────────────
echo "🧹 Deleting existing Kind cluster '$CLUSTER_NAME' (if any)..."
kind delete cluster --name "$CLUSTER_NAME" || true

# ─────────────────────────────────────────────────────────────
# 🛠️ Create Kind cluster
# ─────────────────────────────────────────────────────────────
echo "🛠️ Creating '$CLUSTER_NAME' cluster..."
kind create cluster --name "$CLUSTER_NAME" --config clusters/kind-${CLUSTER_NAME}.yaml

# ─────────────────────────────────────────────────────────────
# 🚀 Install Nginx Ingress and MetalLB
# ─────────────────────────────────────────────────────────────
echo "🚀 Installing Nginx Ingress in '$CLUSTER_NAME'..."
kubectl config use-context kind-${CLUSTER_NAME}
kubectl apply -f deploy-ingress-nginx.yaml
sleep 20s

echo "📦 Installing MetalLB in '$CLUSTER_NAME'..."
kubectl apply -f metallb/my-metallb.yaml
sleep 20s
kubectl apply -f metallb/metallb-config-master.yaml
sleep 5s

# ─────────────────────────────────────────────────────────────
# 🚀 Install ArgoCD
# ─────────────────────────────────────────────────────────────
echo "🚀 Installing ArgoCD in '$CLUSTER_NAME'..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  -f argocd_values.yaml \
  --namespace argocd \
  --version $ARGOCD_VERSION \
  --create-namespace \
  --wait

# Give it a bit of time to settle
echo "⏱ Waiting a bit for ArgoCD components to fully initialize..."
sleep 5s

# ─────────────────────────────────────────────────────────────
# 🔐 Login to ArgoCD
# ─────────────────────────────────────────────────────────────
echo "🔐 Logging into ArgoCD..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login ${ARGOCD_DOMAIN}:${ARGOCD_PORT} --username admin --password $ARGOCD_PASSWORD --insecure --grpc-web

# ─────────────────────────────────────────────────────────────
# ✅ Wrap-up
# ─────────────────────────────────────────────────────────────
echo ""
echo "✅ Cluster and applications deployed successfully!"
echo ""
echo "🌐 Access your services:"
echo "  ▶ ArgoCD             : https://${ARGOCD_DOMAIN}:${ARGOCD_PORT}/"
echo "  ▶ Grafana            : https://${GRAFANA_DOMAIN}:8443/"
echo "  ▶ Thanos Querier     : https://${QUERIER_THANOS_DOMAIN}:8443/"
echo "  ▶ MinIO Console      : http://${MINIO_DOMAIN}/"
echo ""

echo "💾 Saving ArgoCD credentials to '${CREDENTIALS_FILE}'..."
rm -f $CREDENTIALS_FILE
{
  echo "ArgoCD URL       --> https://${ARGOCD_DOMAIN}:${ARGOCD_PORT}/"
  echo "ArgoCD User      --> admin"
  echo "ArgoCD Password  --> $ARGOCD_PASSWORD"
  echo "Grafana User     --> admin"
  echo "Grafana Password --> $> kubectl get secret grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d"
} >> $CREDENTIALS_FILE
