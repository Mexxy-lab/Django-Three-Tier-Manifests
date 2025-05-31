#!/bin/bash
set -e

NAMESPACE=django

echo "Creating namespace..."
kubectl apply -f namespace.yaml

echo "Applying secrets..."
kubectl apply -f secrets.yaml -n $NAMESPACE

echo "Applying MySQL StatefulSet and Service..."
kubectl apply -f mysql-statefulset.yaml -n $NAMESPACE

echo "Waiting for MySQL pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=mysql -n $NAMESPACE --timeout=120s

MYSQL_POD=$(kubectl get pods -n $NAMESPACE -l app=mysql -o jsonpath="{.items[0].metadata.name}")
MYSQL_ROOT_PASSWORD=$(kubectl get secret django-secrets -n $NAMESPACE -o jsonpath="{.data.MYSQL_ROOT_PASSWORD}" | base64 --decode)

kubectl exec -i "$MYSQL_POD" -n "$NAMESPACE" -- \
  sh -c "mysql -h 127.0.0.1 -u root -p\"$MYSQL_ROOT_PASSWORD\" -e 'CREATE DATABASE IF NOT EXISTS django_database;'"

echo "Applying Django backend deployment and service..."
kubectl apply -f backend-manifests/backend.yaml -n $NAMESPACE

echo "Applying frontend deployment and service..."
kubectl apply -f frontend-manifests/frontend.yaml -n $NAMESPACE

echo "Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

echo "Waiting for cert-manager webhook to be ready..."
kubectl rollout status deployment cert-manager-webhook -n cert-manager --timeout=180s

echo "Applying ClusterIssuer..."
kubectl apply -f cluster-issuer.yaml -n $NAMESPACE

echo "Installing Ingress controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml

echo "Waiting for ingress-nginx-controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s

echo "Applying Ingress..."
kubectl apply -f ingress.yaml -n $NAMESPACE

echo "✅ cluster resources deployed successfully."

echo "Waiting for Django backend pod to be ready..."
kubectl wait --for=condition=Ready pod -l app=django -n $NAMESPACE --timeout=180s

BACKEND_POD=$(kubectl get pods -n $NAMESPACE -l app=django -o jsonpath="{.items[0].metadata.name}")

echo "Running Django migrations and setup... of superuser"

kubectl exec -it "$BACKEND_POD" -n "$NAMESPACE" -- python manage.py makemigrations api
kubectl exec -it "$BACKEND_POD" -n "$NAMESPACE" -- python manage.py migrate
kubectl exec -it "$BACKEND_POD" -n "$NAMESPACE" -- python manage.py migrate api
kubectl exec -it "$BACKEND_POD" -n "$NAMESPACE" -- python manage.py createsuperuser
kubectl exec -it "$BACKEND_POD" -n "$NAMESPACE" -- python manage.py seed_items

echo "✅ Deployment complete and Django setup finished successfully."