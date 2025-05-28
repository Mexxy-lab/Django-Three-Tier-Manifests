
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

Deploy frontend, backend, MySQL, and Ingress resources.

```bash
 kubectl apply -f frontend-manifests/frontend.yaml -n django
 kubectl apply -f secrets.yaml -n django                      | Has to be deployed first before deploying the backend
  kubectl apply -f backend-manifests/backend.yaml -n django
   kubectl apply -f mysql-statefulset.yaml -n django          | Used to deploy the mysql
    kubectl apply -f ingress.yaml -n django                    | Used to deploy ingress 

Once deployed, **migrate the database** in the Django backend: You need to create the database table first 

```bash
kubectl exec -it mysql-0 -n django -- mysql -u root -p        | Login with password set in secrets file. 
CREATE DATABASE django_database;

kubectl exec -it django-backend-559844868-9gdgj -n django -- python manage.py makemigrations -n django
kubectl exec -it django-backend-559844868-9gdgj -n django -- python manage.py migrate
```

You can find the backend pod name using:

```bash
kubectl get pods -n django
```

#### Example Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: django
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  rules:
  - host: django.pumej.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
      - path: /api
        pathType: ImplementationSpecific
        backend:
          service:
            name: backend-service
            port:
              number: 5000
  tls:
  - hosts:
    - django.pumej.com
    secretName: django-tls
```

Apply Ingress:

```bash
kubectl apply -f ingress.yaml
```

---

### 2️⃣ Install cert-manager & ClusterIssuer

Install cert-manager (for Let’s Encrypt TLS):

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml
```

#### Create `cluster-issuer.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: django
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: pumej1985@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

Apply it:

```bash
kubectl apply -f cluster-issuer.yaml
```

---

### 3️⃣ Port-Forward NGINX Ingress Locally

```bash
kubectl port-forward svc/ingress-nginx-controller 8000:80 -n ingress-nginx
```

---

### 4️⃣ Configure Cloudflare Tunnel

#### Install `cloudflared`

```bash
sudo apt update
sudo apt install -y cloudflared
# OR
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get install -y cloudflared
```

#### Authenticate & Create Tunnel

```bash
cloudflared tunnel login
cloudflared tunnel create django-tunnel         | Used to generate the Tunnel ID 
cloudflared tunnel route dns django-tunnel django.pumej.com         | Used this to update your cname to point to your domain 
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
    service: http://127.0.0.1:8086
  - service: http_status:404
```

---

### 5️⃣ Start Cloudflared as a Service

```bash
sudo cloudflared service install
sudo systemctl start cloudflared
sudo systemctl status cloudflared
```

Ensure status is `active (running)`.

---

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

---

## ✅ Final Checks

- DNS resolves:

  ```bash
  dig CNAME django.pumej.com +short
  ```

- Check ingress:

  ```bash
  kubectl get ingress -n django
  ```

Now visit:  
🔗 <https://django.pumej.com>

You should see your frontend served over HTTPS.

---

## 🧼 Cleanup

To remove everything:

```bash
cloudflared tunnel delete django-tunnel
kubectl delete -f app-ingress.yaml
kubectl delete -f cluster-issuer.yaml
```

---

## 📧 Contact

**Author**: Emeka U.
📬 <pumej1985@gmail.com>  
🌐 [https://github.com/Mexxy-lab](https://github.com/emeka-umejiofor)
