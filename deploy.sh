#!/bin/bash
set -e

NAMESPACE=django

echo "Creating namespace..."
kubectl apply -f namespace.yaml

echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

echo "Waiting for cert-manager pods to be ready..."
kubectl wait --namespace cert-manager --for=condition=Ready pod --all --timeout=120s

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

echo "Applying ingress..."
kubectl apply -f ingress.yaml -n $NAMESPACE

echo "All resources applied successfully."

echo "You can check pods status with:"
echo "  kubectl get pods -n $NAMESPACE"
