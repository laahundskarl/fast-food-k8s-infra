# FastFood Kubernetes Infrastructure

![Terraform](https://img.shields.io/badge/Terraform-1.5.0-7B42BC)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28-326CE5)
![Docker](https://img.shields.io/badge/Docker-ECR-2496ED)

## 📋 Sobre

Este repositório contém a infraestrutura Kubernetes (EKS) para o projeto FastFood, responsável por orquestrar a aplicação principal `fast-food` que roda em containers. Implementa cluster EKS gerenciado pela AWS com integração ao ECR para armazenamento de imagens Docker.

## 🎯 Arquitetura Kubernetes

### Componentes Principais

```
┌─────────────────────────────────────────────────┐
│              Application Load Balancer           │
│                  (AWS ALB)                       │
└────────────────────┬────────────────────────────┘
                     │
         ┌───────────▼──────────┐
         │   Ingress Controller  │
         │   (AWS ALB Ingress)   │
         └───────────┬───────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼────┐      ┌───▼────┐      ┌───▼────┐
│ Pod 1  │      │ Pod 2  │      │ Pod 3  │
│fast-   │      │fast-   │      │fast-   │
│food    │      │food    │      │food    │
└────────┘      └────────┘      └────────┘
    │                │                │
    └────────────────┼────────────────┘
                     │
         ┌───────────▼──────────┐
         │   MySQL RDS (main)   │
         │   fastfood_main      │
         └──────────────────────┘
```

## 🏗️ Recursos Provisionados

### Amazon EKS (Elastic Kubernetes Service)

#### Cluster Configuration
- **Kubernetes Version**: 1.28
- **Node Group**: Managed Node Group
- **Instance Type**: t3.medium (2 vCPU, 4GB RAM)
- **Scaling**:
  - Min: 2 nodes
  - Max: 4 nodes
  - Desired: 2 nodes
- **Networking**: VPC privada com subnets públicas e privadas

#### Add-ons Instalados
- **VPC CNI**: Networking plugin
- **CoreDNS**: DNS interno do cluster
- **kube-proxy**: Network proxy
- **AWS Load Balancer Controller**: Integração com ALB/NLB

### Amazon ECR (Elastic Container Registry)

#### Repositórios
- **fast-food**: Imagens da aplicação principal
- **Lifecycle Policy**: Mantém últimas 10 imagens, remove antigas
- **Scan on Push**: Scan de vulnerabilidades automático
- **Encryption**: AES-256

## 📦 Manifests Kubernetes

### Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fast-food
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fast-food
  template:
    spec:
      containers:
      - name: fast-food
        image: <account>.dkr.ecr.us-east-1.amazonaws.com/fast-food:latest
        ports:
        - containerPort: 3000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: url
```

### Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: fast-food-service
spec:
  type: LoadBalancer
  selector:
    app: fast-food
  ports:
  - port: 80
    targetPort: 3000
```

### Ingress (ALB)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fast-food-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: fast-food-service
            port:
              number: 80
```

## 🏗️ Estrutura do Repositório

```
fast-food-k8s-infra/
├── terraform/
│   ├── providers.tf           → Configuração AWS
│   ├── variables.tf           → Variáveis de configuração
│   ├── vpc.tf                 → VPC e Networking
│   ├── eks-cluster.tf         → Cluster EKS
│   ├── eks-node-group.tf      → Node Group
│   ├── ecr.tf                 → Container Registry
│   ├── iam-roles.tf           → IAM Roles e Policies
│   └── outputs.tf             → Outputs (kubeconfig, etc)
├── k8s/
│   ├── deployment.yaml        → Deployment da aplicação
│   ├── service.yaml           → Service (LoadBalancer)
│   ├── ingress.yaml           → Ingress (ALB)
│   ├── configmap.yaml         → ConfigMaps
│   └── secrets.yaml           → Secrets (template)
└── .github/workflows/
    └── terraform-deploy.yml   → CI/CD Terraform
```

## 🔒 Segurança

### Network Security
- **Private Subnets**: Nodes em subnets privadas
- **Security Groups**: Regras restritivas
- **Network Policies**: Isolamento de pods
- **VPC Flow Logs**: Auditoria de tráfego

### IAM & RBAC
- **IAM Roles for Service Accounts (IRSA)**: Permissões granulares
- **RBAC**: Role-Based Access Control
- **Pod Security Standards**: Enforced
- **Secrets Encryption**: KMS encryption at rest

### Container Security
- **ECR Image Scanning**: Vulnerabilidades detectadas
- **Non-root Containers**: Containers não rodam como root
- **Read-only Root Filesystem**: Filesystem imutável
- **Resource Limits**: CPU e Memory limits definidos

## 🚀 Deploy

### Pré-requisitos
- Terraform 1.5.0+
- AWS CLI configurado
- kubectl instalado
- Credenciais AWS com permissões para EKS e ECR

### 1. Provisionar Infraestrutura

```bash
# Inicializar Terraform
cd terraform
terraform init

# Validar configuração
terraform validate

# Planejar mudanças
terraform plan

# Aplicar infraestrutura
terraform apply

# Configurar kubectl
aws eks update-kubeconfig --name fastfood-cluster --region us-east-1
```

### 2. Deploy da Aplicação

```bash
# Aplicar manifests Kubernetes
cd ../k8s
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Verificar status
kubectl get pods
kubectl get svc
kubectl get ingress
```

### 3. Build e Push de Imagem

```bash
# Login no ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

# Build da imagem
docker build -t fast-food:latest .

# Tag da imagem
docker tag fast-food:latest <account>.dkr.ecr.us-east-1.amazonaws.com/fast-food:latest

# Push para ECR
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/fast-food:latest

# Atualizar deployment
kubectl rollout restart deployment/fast-food
```

## 🔄 CI/CD

Este repositório possui workflow automatizado de CI/CD via GitHub Actions:

### Workflow: `terraform-deploy.yml`
- **Trigger**: Merge para `modulo_4`
- **Jobs**:
  - Validação Terraform
  - Plan (preview de mudanças)
  - Apply (deploy automático de infraestrutura)
  - Update kubeconfig
  - Deploy manifests Kubernetes

### Workflow: `deploy-app.yml` (no repo fast-food)
- **Trigger**: Merge para `modulo_4`
- **Jobs**:
  - Build Docker image
  - Push para ECR
  - Update Kubernetes deployment
  - Rollout restart

## 📊 Monitoramento

### CloudWatch Container Insights
- **Métricas de Cluster**:
  - CPU e Memory utilization
  - Network I/O
  - Pod count
  - Node status

- **Métricas de Aplicação**:
  - Request rate
  - Error rate
  - Response time
  - Container restarts

### Logs
- **Application Logs**: CloudWatch Logs via Fluent Bit
- **Cluster Logs**: Control plane logs
- **Audit Logs**: Kubernetes API audit

## 🔧 Troubleshooting

### Verificar Status do Cluster
```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

### Logs de Pods
```bash
kubectl logs -f deployment/fast-food
kubectl describe pod <pod-name>
```

### Eventos do Cluster
```bash
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Conectar ao Pod
```bash
kubectl exec -it <pod-name> -- /bin/sh
```

## 🔗 Integração com Outros Serviços

### Conexão com RDS
- Pods se conectam ao RDS via endpoint privado
- Credenciais armazenadas em Kubernetes Secrets
- Connection pooling configurado

### Comunicação com Lambdas
- Lambdas são chamados via API Gateway
- Autenticação via JWT tokens
- Retry logic implementado

## 📈 Escalabilidade

### Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fast-food-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fast-food
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Cluster Autoscaler
- Escala nodes automaticamente baseado em demanda
- Min: 2 nodes, Max: 4 nodes
- Scale down após 10 minutos de baixa utilização

## 👥 Equipe

**Grupo 277 - SOAT FIAP**

- Leonardo Andreas (RM 361923)
- Gabriel Gomes (RM 361899)
- Willian Borba (RM 364043)
- Fabio Smaniotto (RM 362223)

## 📄 Licença

Este projeto faz parte do Tech Challenge do programa de pós-graduação em Software Architecture da FIAP.
