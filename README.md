
# 🌐 Exposing Minikube-Based Application via Cloudflare Tunnel

This guide walks you through deploying a multi-tier application (frontend, backend, MySQL) on Kubernetes using Minikube, with public HTTPS access via Cloudflare Tunnel and TLS certificates from Let's Encrypt.

---

## 🧱 Architecture Overview

- **Kubernetes**: Minikube on Ubuntu 22.04  
- **Ingress**: NGINX Ingress installed from GitHub YAML  
- **App Components**:
  - Frontend (port `80`)
  - Backend (port `8000`)
  - MySQL (port `3306`)
- **Domain**: `pumej.com` managed via Cloudflare  
- **Tunnel Access**: `django.pumej.com` via Cloudflare Tunnel

---

## ✅ Prerequisites

- Minikube running locally
- Domain registered on Cloudflare (e.g., `pumej.com`)
- Cloudflare account & API access
- `cloudflared` installed
- Ingress NGINX installed via YAML:

  ```bash
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
  ```

---

## 🔧 Step-by-Step Setup

### 1️⃣ Deploy Your App

Deploy frontend, backend, MySQL, and Ingress resources. Follow the below sequence:

```bash
kubectl apply -f namespace.yaml
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml
kubectl apply -f cluster-issuer.yaml
kubectl apply -f secrets.yaml
kubectl apply -f mysqlstatefulset.yaml
kubectl apply -f backend-manifests/backend.yaml
kubectl apply -f frontend-manifests/frontend.yaml
kubectl apply -f ingress.yaml
```

Or run the deploy script on the terminal

```bash
./deploy.sh
```

Once deployed, **migrate the database** in the Django backend: You need to create the database table first

```bash
kubectl exec -it mysql-0 -n django -- mysql -u root -p        | Login with password set in secrets file. 
CREATE DATABASE django_database;

kubectl exec -it django-backend-559844868-9gdgj -n django -- python manage.py makemigrations -n django
kubectl exec -it django-backend-559844868-9gdgj -n django -- python manage.py migrate
kubectl exec -it django-backend-559844868-9gdgj -n django -- python manage.py createsuperuser
```

You can find the backend pod name using:

```bash
kubectl get pods -n django
kubectl get svc -n ingress-nginx
```

### 2️⃣ Install cert-manager & ClusterIssuer

Install cert-manager (for Let’s Encrypt TLS):

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml
```

### 3️⃣ Port-Forward NGINX Ingress Locally

```bash
kubectl port-forward svc/ingress-nginx-controller 8000:80 -n ingress-nginx
```

### 4️⃣ Configure Cloudflare Tunnel

#### Install `cloudflared`

```bash
sudo apt update
sudo apt install -y cloudflared
```

#### Authenticate & Create Tunnel

```bash
cloudflared tunnel login
cloudflared tunnel create django-tunnel         | Used to generate the Tunnel ID 
```

#### Configure Tunnel

```bash
sudo mkdir -p /etc/cloudflared
sudo nano /etc/cloudflared/config.yml
```

Paste the following:

```yaml
tunnel: XXX-ID
credentials-file: /home/nepra/.cloudflared/XXX.json

ingress:
  - hostname: django.pumej.com
    service: http://127.0.0.1:Nodeport
  - service: http_status:404
```

### 5️⃣ Start Cloudflared as a Service

```bash
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

Ensure status is `active (running)`.

### 6️⃣ Configure Cloudflare DNS

Link your domain to the tunnel:

```bash
cloudflared tunnel route dns django-tunnel django.pumej.com
```

Or add manually via Cloudflare Dashboard:

- Type: `CNAME`
- Name: `django`
- Target: `<your-tunnel-id>.cfargotunnel.com`
- Proxy status: **Proxied**

## ✅ Final Checks

- DNS resolves:

  ```bash
  dig CNAME django.pumej.com
  ```

- Check ingress:

  ```bash
  kubectl get ingress -n django
  kubectl describe ingress django-ingress -n django
  ```

Now visit:  
🔗 <https://django.pumej.com>

You should see your frontend served over HTTPS.

## 🧼 Cleanup

To remove everything:

```bash
cloudflared tunnel delete django-tunnel
kubectl delete -f app-ingress.yaml
kubectl delete -f cluster-issuer.yaml
```

## 📧 Contact

**Author**: Emeka U.
📬 <pumej1985@gmail.com>  
🌐 [https://github.com/Mexxy-lab](https://github.com/emeka-umejiofor)
