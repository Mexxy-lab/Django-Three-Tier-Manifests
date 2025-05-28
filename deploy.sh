#!/bin/bash
set -e

NAMESPACE=django

echo "Creating namespace..."
kubectl apply -f namespace.yaml

echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

echo "Waiting for cert-manager webhook to be ready..."

kubectl rollout status deployment cert-manager-webhook -n cert-manager --timeout=180s

echo "Checking if cert-manager webhook is ready..."

until kubectl run curl --image=radial/busyboxplus:curl -i --rm --restart=Never -- \
    curl -fsS https://cert-manager-webhook.cert-manager.svc:443/healthz --insecure; do
  echo "Webhook not ready yet. Retrying in 10s..."
  sleep 10
done

echo "Webhook is ready!"

echo "Applying ClusterIssuer..."
kubectl apply -f cluster-issuer.yaml

echo "Applying secrets..."
kubectl apply -f secrets.yaml -n $NAMESPACE

echo "Applying MySQL StatefulSet and Service..."
kubectl apply -f mysql-statefulset.yaml -n $NAMESPACE

echo "Applying Django backend deployment and service..."
kubectl apply -f backend-manifests/backend.yaml -n $NAMESPACE

echo "Applying frontend deployment and service..."
kubectl apply -f frontend-manifests/frontend.yaml -n $NAMESPACE

echo "Applying Ingress controller for ingress service..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

echo "Waiting for ingress-nginx-controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "Applying ingress..."
kubectl apply -f ingress.yaml -n $NAMESPACE

echo "All resources applied successfully."

echo "You can check pods status with:"
echo "  kubectl get pods -n $NAMESPACE"
