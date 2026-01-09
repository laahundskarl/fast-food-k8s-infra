# FastFood K8s Infrastructure - Infraestrutura Kubernetes

![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5)
![AWS EKS](https://img.shields.io/badge/AWS-EKS-FF9900)
![AWS ECR](https://img.shields.io/badge/AWS-ECR-FF9900)

## 📋 Sobre o Repositório

Repositório de infraestrutura como código (IaC) responsável pelo provisionamento e gerenciamento de toda a infraestrutura Kubernetes do sistema FastFood na AWS, incluindo cluster EKS, registry ECR e recursos de orquestração.

## 🎯 Responsabilidades

### Provisionamento de Cluster
- **Amazon EKS**: Cluster Kubernetes gerenciado
- **Node Groups**: Grupos de nós EC2 para workloads
- **Amazon ECR**: Registry privado de imagens Docker
- **VPC e Networking**: Configuração de rede para o cluster

### Recursos Kubernetes
- **Deployments**: Manifestos de deployment das aplicações
- **Services**: Exposição de serviços (LoadBalancer, ClusterIP)
- **ConfigMaps**: Configurações de aplicação
- **Secrets**: Credenciais e dados sensíveis
- **HPA**: Horizontal Pod Autoscaler para escalabilidade
- **Metrics Server**: Coleta de métricas para HPA

### Gerenciamento
- **Auto-scaling**: Escalabilidade horizontal automática
- **Load Balancing**: Distribuição de tráfego
- **High Availability**: Múltiplas réplicas e zonas
- **Monitoring**: Integração com CloudWatch

## 🏗️ Arquitetura

### Estrutura do Repositório

```
terraform/
├── main.tf              → Recursos principais (EKS, ECR)
├── outputs.tf           → Outputs dos recursos criados
├── providers.tf         → Configuração de providers AWS
├── variables.tf         → Variáveis de configuração
└── terraform.tfvars.example → Exemplo de variáveis

k8s/
├── deployment.yaml      → Deployment da aplicação
├── service.yaml         → Service LoadBalancer
├── configmap.yaml       → ConfigMaps
├── secrets.yaml         → Secrets (template)
├── hpa.yaml             → Horizontal Pod Autoscaler
└── metrics-server.yaml  → Metrics Server
```

### Diagrama de Infraestrutura

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              Amazon EKS Cluster                     │    │
│  │                                                     │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────┐│    │
│  │  │  Node Group  │  │  Node Group  │  │  Node    ││    │
│  │  │  us-east-1a  │  │  us-east-1b  │  │  Group   ││    │
│  │  └──────┬───────┘  └──────┬───────┘  └────┬─────┘│    │
│  │         │                 │                │      │    │
│  │  ┌──────▼─────────────────▼────────────────▼────┐ │    │
│  │  │           FastFood Pods (2+ replicas)        │ │    │
│  │  │  ┌────────┐  ┌────────┐  ┌────────┐         │ │    │
│  │  │  │ Pod 1  │  │ Pod 2  │  │ Pod N  │         │ │    │
│  │  │  └────────┘  └────────┘  └────────┘         │ │    │
│  │  └───────────────────┬──────────────────────────┘ │    │
│  │                      │                            │    │
│  │  ┌───────────────────▼──────────────────────────┐ │    │
│  │  │         LoadBalancer Service                 │ │    │
│  │  └───────────────────┬──────────────────────────┘ │    │
│  └────────────────────────┼──────────────────────────┘    │
│                           │                               │
│  ┌────────────────────────▼──────────────────────────┐   │
│  │          Application Load Balancer (ELB)          │   │
│  └────────────────────────┬──────────────────────────┘   │
│                           │                               │
│  ┌────────────────────────▼──────────────────────────┐   │
│  │          Amazon ECR (Container Registry)          │   │
│  │         fastfood-api:latest                       │   │
│  └───────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 🛠️ Stack Tecnológica

### Infrastructure as Code
- **Terraform**: >= 1.0
- **AWS Provider**: ~> 5.0
- **Kubernetes Provider**: ~> 2.0

### AWS Services
- **Amazon EKS**: Kubernetes gerenciado
  - Version: 1.28+
  - Node Type: t3.medium (configurável)
  - Min Nodes: 2
  - Max Nodes: 4

- **Amazon ECR**: Container Registry
  - Image Scanning: Habilitado
  - Lifecycle Policies: Configurado

- **Elastic Load Balancer**: Distribuição de tráfego
- **CloudWatch**: Logs e métricas
- **IAM**: Roles e políticas

### Kubernetes Resources
- **Deployments**: Gerenciamento de pods
- **Services**: LoadBalancer para acesso externo
- **HPA**: Auto-scaling baseado em CPU/memória
- **Metrics Server**: Coleta de métricas
- **ConfigMaps/Secrets**: Configurações

## 🚀 Como Usar

### Pré-requisitos
- Terraform >= 1.0 instalado
- AWS CLI configurado com credenciais válidas
- kubectl instalado
- Permissões IAM necessárias:
  - `AmazonEKSClusterPolicy`
  - `AmazonEKSWorkerNodePolicy`
  - `AmazonEC2ContainerRegistryFullAccess`
  - `AmazonVPCFullAccess`

### Provisionamento da Infraestrutura

```bash
# 1. Clonar repositório
git clone https://github.com/fiap-software-architecture-tech/fast-food-k8s-infra.git
cd fast-food-k8s-infra/terraform

# 2. Copiar e configurar variáveis
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars com suas configurações

# 3. Inicializar Terraform
terraform init

# 4. Validar configuração
terraform validate

# 5. Planejar mudanças
terraform plan

# 6. Aplicar infraestrutura
terraform apply
```

### Configurar kubectl

```bash
# Atualizar kubeconfig para o cluster EKS
aws eks update-kubeconfig --region us-east-1 --name fast-food-cluster-prd

# Verificar conexão
kubectl get nodes
```

### Deploy da Aplicação

```bash
cd ../k8s

# 1. Aplicar ConfigMaps
kubectl apply -f configmap.yaml

# 2. Aplicar Secrets (após configurar)
kubectl apply -f secrets.yaml

# 3. Deploy da aplicação
kubectl apply -f deployment.yaml

# 4. Expor serviço
kubectl apply -f service.yaml

# 5. Configurar HPA
kubectl apply -f hpa.yaml

# 6. Deploy Metrics Server (se necessário)
kubectl apply -f metrics-server.yaml
```

### Verificar Deploy

```bash
# Ver pods
kubectl get pods

# Ver serviços
kubectl get svc

# Obter URL do LoadBalancer
kubectl get svc fastfood-loadbalancer

# Ver HPA
kubectl get hpa

# Ver métricas
kubectl top pods
kubectl top nodes
```

## 📊 Recursos Kubernetes

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastfood-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fastfood-api
  template:
    spec:
      containers:
      - name: fastfood-api
        image: <ECR_URI>:latest
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

### HPA (Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: fastfood-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: fastfood-api
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

## 🔒 Segurança

### Boas Práticas Implementadas
- ✅ **Private Subnets**: Nodes em subnets privadas
- ✅ **Security Groups**: Acesso restrito ao cluster
- ✅ **IAM Roles**: Permissões granulares para nodes
- ✅ **ECR Scanning**: Scan automático de vulnerabilidades
- ✅ **Secrets Management**: Kubernetes Secrets para dados sensíveis
- ✅ **Network Policies**: Isolamento de rede (configurável)
- ✅ **RBAC**: Controle de acesso baseado em roles

### Recomendações
- Use **AWS Secrets Manager** para secrets sensíveis
- Configure **Pod Security Policies**
- Habilite **Audit Logging**
- Implemente **Network Policies**
- Use **Private ECR** para imagens

## 📊 Monitoramento

### CloudWatch Metrics
- Cluster CPU/Memory
- Node CPU/Memory
- Pod Count
- Network I/O

### Kubernetes Metrics
```bash
# Métricas de pods
kubectl top pods

# Métricas de nodes
kubectl top nodes

# Logs de pods
kubectl logs -f <pod-name>

# Eventos do cluster
kubectl get events
```

## 🔧 Troubleshooting

### Pods não iniciam
```bash
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### HPA não funciona
```bash
# Verificar Metrics Server
kubectl get deployment metrics-server -n kube-system
kubectl logs -n kube-system -l k8s-app=metrics-server

# Verificar métricas
kubectl top nodes
```

### LoadBalancer sem IP externo
```bash
kubectl describe svc fastfood-loadbalancer
# Verificar security groups e subnets
```

## 💰 Estimativa de Custos

### EKS Cluster
- **Control Plane**: ~$73/mês

### EC2 Nodes
- **t3.medium (2 nodes)**: ~$60-80/mês
- **Auto-scaling**: Variável baseado em carga

### Load Balancer
- **ALB**: ~$20-30/mês

### ECR
- **Storage**: ~$1-5/mês

**Total Estimado**: ~$150-200/mês

### Otimização de Custos
- Use instâncias Spot para ambientes de dev
- Configure auto-scaling adequadamente
- Use t3.small em dev
- Delete recursos quando não estiver usando

## 🔗 Repositórios Relacionados

- **[fast-food](https://github.com/fiap-software-architecture-tech/fast-food)** - Aplicação Principal
- **[fast-food-auth](https://github.com/fiap-software-architecture-tech/fast-food-auth)** - Autenticação Lambda
- **[fast-food-order](https://github.com/fiap-software-architecture-tech/fast-food-order)** - Microsserviço de Pedidos
- **[fast-food-payment](https://github.com/fiap-software-architecture-tech/fast-food-payment)** - Microsserviço de Pagamentos
- **[fast-food-cook-to-order](https://github.com/fiap-software-architecture-tech/fast-food-cook-to-order)** - Microsserviço de Cozinha
- **[fast-food-db-infra](https://github.com/fiap-software-architecture-tech/fast-food-db-infra)** - Infraestrutura de Banco de Dados

## 🧹 Cleanup

### Destruir Infraestrutura

```bash
# 1. Remover recursos Kubernetes primeiro
cd k8s
kubectl delete -f .

# 2. Destruir cluster EKS
cd ../terraform
terraform destroy

# ATENÇÃO: Isso removerá todo o cluster e recursos associados!
```

## 👥 Equipe

**Grupo 277 - SOAT FIAP**

- Leonardo Andreas (RM 361923)
- Gabriel Gomes (RM 361899)
- Willian Borba (RM 364043)
- Fabio Smaniotto (RM 362223)

## 📄 Licença

Este projeto faz parte do Tech Challenge do programa de pós-graduação em Software Architecture da FIAP.
