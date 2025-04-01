# Django Application Deployment with Minikube, Helm, and ArgoCD

## 🚀 Introduction
Set up a **multi-node Kubernetes cluster** using Minikube, deploy **ArgoCD**, manage **secrets** with Bitnami Sealed Secrets, and deploy a **Django admin application** using Helm and GitOps.

---

## 📌 Prerequisites
Ensure you have the following installed on your system:
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [ArgoCD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [Kubeseal](https://github.com/bitnami-labs/sealed-secrets)
- Git and a **Git repository** for storing Helm charts and secrets

---

## 🏗 Setting up a Multi-Node Minikube Cluster

1️⃣ **Install Minikube**
Follow the [official Minikube installation guide](https://minikube.sigs.k8s.io/docs/start/).

2️⃣ **Start Minikube with 3 Nodes (1 Master, 2 Workers)**
```sh
minikube start --nodes 3 -p multinode-demo-new
```

3️⃣ **Verify Cluster Status**
```sh
minikube status -p multinode-demo-new
```
![djapp1](https://github.com/user-attachments/assets/ec808ed6-e127-4ec4-8a4e-f8d26a0ec429)

---

## 🏗 Setting Up Ingress and DNS

1️⃣ **enable ingress & nginx ingress controller**
```sh
minikube addons enable ingress -p multinode-demo-new
```

2️⃣ **Add a DNS entry in /etc/hosts for the DNS host specified in the Ingress**
```sh
127.0.0.1 test.djangoapp.com
```

---

## 🚀 Deploying ArgoCD

1️⃣ **Create ArgoCD Namespace**
```sh
kubectl create namespace argocd
```

2️⃣ **Install ArgoCD**
```sh
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

3️⃣ **Access ArgoCD UI**
```sh
kubectl port-forward -n argocd pods/argo-server-pod  8080:8080
```

4️⃣ **Retrieve Initial Admin Password**
```sh
kubectl get secret argocd-initial-admin-secret -n argocd -o yaml | grep "password:" | awk '{print $2}' | base64 -d
```
Use **admin** as the username and the decoded password to log in to ArgoCD UI.


---

## 🔒 Managing Secrets with Sealed Secrets

1️⃣ **Add Bitnami Sealed Secrets Helm Repository to ArgoCD**

- Add the repo inside ArgoCD UI or via CLI.

2️⃣ **Deploy Sealed Secrets Controller**

![assg2](https://github.com/user-attachments/assets/9951ded9-9ab6-4dcd-88b9-c7de61b4c94b)
![assg8](https://github.com/user-attachments/assets/0af67fa9-cd25-4afb-906d-fdd28e6b4268)

3️⃣ **Retrieve Sealed Secret Certificate**
```sh
kubectl get secret sealed-secrets-key -n kube-system -o jsonpath='{.data.tls\.crt}' | base64 -d > secret.crt
```

4️⃣ **Install Kubeseal**
```sh
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.28.0/kubeseal-0.28.0-linux-amd64.tar.gz"
tar -xvzf kubeseal-0.28.0-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

5️⃣ **Create & Seal Kubernetes Secrets**
Create **postgres-db-secret.yml** and **django-admin-secret.yml**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
type: Opaque
data:
  POSTGRES_DB: <base64-encoded-database>
  POSTGRES_USER: <base64-encoded-username>
  POSTGRES_PASSWORD: <base64-encoded-password>
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: admin-secret
type: Opaque
data:
  DATABASE_NAME: <base64-encoded-database>
  DATABASE_USER: <base64-encoded-username>
  DATABASE_PASSWORD: <base64-encoded-password>
  DATABASE_HOST: <base64-encoded-host>
  DATABASE_PORT: <base64-encoded-port>
  SECRET_KEY: <base64-encoded-key>
  DEBUG: <base64-encoded-debug>
  SUPERUSER_USERNAME: <base64-encoded-super-username>
  SUPERUSER_EMAIL: <base64-encoded-user-email>
  SUPERUSER_PASSWORD: <base64-encoded-user-password>
```
Seal the secrets:
```sh
kubeseal -o yaml --cert secret.crt --scope cluster-wide < postgres-db-secret.yml > postgres-db-secret-seal.yml
kubeseal -o yaml --cert secret.crt --scope cluster-wide < django-admin-secret.yml > django-admin-secret-seal.yml
```

---
## 🎯 Init Changes
1️⃣ **Add Configmap Changes on Kubernetes**
- Make the changes in helm\charts\postgresdb\templates\init-db-cm.yml
```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.configMapName }}
data: 
  postgres_init.sql: |-
    GRANT ALL PRIVILEGES ON DATABASE <database-name> TO <database-user>;
    GRANT ALL PRIVILEGES ON SCHEMA public TO <database-user>;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO <database-user>;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO <database-user>;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO <database-user>;
```
2️⃣ **Add Changes on Docker-Compose**
- Make the changes in scripts\init-scripts\init.sql  
```sh
    GRANT ALL PRIVILEGES ON DATABASE <database-name> TO <database-user>;
    GRANT ALL PRIVILEGES ON SCHEMA public TO <database-user>;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO <database-user>;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO <database-user>;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO <database-user>;
```
## 🎯 Deploy Django Application with Helm & ArgoCD

1️⃣ **Create ArgoCD Application using Git Repository**

- **Option 1: ArgoCD UI**
  - Go to **Applications → Create Application**
  - Enter details: **Name**, **Project**, **Git Repository URL**, and Helm chart path.
  - Enable **Auto-Sync** for continuous deployment.

- **Option 2: ArgoCD CLI**
```sh
argocd app create django-app \
  --repo https://github.com/dilafar/devops-assessment.git \
  --path helm \
  --revision main \
  --helm-set-file charts/djangoapp/values.yaml \
  --helm-set-file charts/postgresdb/values.yaml \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --sync-options CreateNamespace=true \
  --project default
```
- **Option 3: Kubectl Apply**
```sh
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: django-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/dilafar/devops-assessment.git
    path: helm
    targetRevision: main
    helm:
      valueFiles:
        - charts/djangoapp/values.yaml
        - charts/postgresdb/values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: default
    name: in-cluster
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```
* The repository URL is the URL of your project's Git repository

2️⃣ **Monitor Deployment**
```sh
argocd app get django-app
```

2️⃣ **Start Ingress Service In Minikube**
```sh
 minikube tunnel -p multinode-demo-new
```
![djapp2](https://github.com/user-attachments/assets/e93e014c-f18f-4764-a526-00694993684a)

3️⃣ **Verify Application Rollout & Rollback**
- Changes in **Helm chart** and **Git repository** will auto-deploy.
- In case of failure, ArgoCD will automatically rollback to the last stable version.
