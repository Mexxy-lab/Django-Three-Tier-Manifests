#!/bin/bash
set -e

NAMESPACE=django

echo "Deleting ingress..."
kubectl delete -f ingress.yaml -n $NAMESPACE --ignore-not-found

echo "Deleting frontend deployment and service..."
kubectl delete -f frontend-manifests/frontend.yaml -n $NAMESPACE --ignore-not-found

echo "Deleting Django backend deployment and service..."
kubectl delete -f backend-manifests/backend.yaml -n $NAMESPACE --ignore-not-found

echo "Deleting MySQL StatefulSet and Service..."
kubectl delete -f mysql-statefulset.yaml -n $NAMESPACE --ignore-not-found

echo "Deleting secrets..."
kubectl delete -f secrets.yaml -n $NAMESPACE --ignore-not-found

echo "Deleting ClusterIssuer..."
kubectl delete -f cluster-issuer.yaml --ignore-not-found

echo "Uninstalling cert-manager..."
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml --ignore-not-found

echo "Deleting ingress controller..."
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml --ignore-not-found

echo "Deleting namespace $NAMESPACE..."
kubectl delete namespace $NAMESPACE --ignore-not-found

echo "Waiting for namespace deletion to complete..."
kubectl wait --for=delete namespace/$NAMESPACE --timeout=120s || echo "Namespace deletion timed out or already deleted."

echo "All resources deleted successfully."
