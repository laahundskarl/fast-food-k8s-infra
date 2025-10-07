#!/bin/bash
set -e

# Tempo de início do deploy - mais robusto
DEPLOY_START_TIME=$(date +%s)
echo "🚀 Deploy iniciado em: $(date) (timestamp: $DEPLOY_START_TIME)"

show_step() {
    local step_time=$(date "+%H:%M:%S")
    echo ""
    echo "⏱️  [$step_time] $1"
}

show_step "[0/10] Configurando kubectl para o cluster EKS..."
aws eks update-kubeconfig --region us-east-1 --name fast-food-cluster-prd

show_step "[1/10] Obtendo URI do ECR e endpoint do RDS..."
ECR_URI=$(terraform output -raw ecr_repository_url 2>/dev/null)

# Obter RDS endpoint do repositório de DB (remote state ou API)
# Por enquanto usar valor padrão, depois conectar via remote state
RDS_ENDPOINT_RAW=$(aws rds describe-db-instances --db-instance-identifier fastfood-db --query 'DBInstances[0].Endpoint.Address' --output text 2>/dev/null)

if [ -z "$ECR_URI" ]; then
    echo "⚠️  Erro: Não foi possível obter ECR URI do terraform output"
    echo "Execute: terraform output ecr_repository_url"
    exit 1
fi

if [ -z "$RDS_ENDPOINT_RAW" ]; then
    echo "⚠️  Erro: Não foi possível obter RDS endpoint"
    echo "Verificar se o RDS foi criado pelo repositório fast-food-db-infra"
    exit 1
fi

# Remove aspas e porta :3306 se estiver presente
RDS_ENDPOINT=$(echo "$RDS_ENDPOINT_RAW" | sed 's/"//g' | sed 's/:3306$//')

echo "📦 Usando imagem: $ECR_URI:latest"
echo "🗄️  RDS endpoint bruto: $RDS_ENDPOINT_RAW"
echo "🗄️  RDS endpoint limpo: $RDS_ENDPOINT"

show_step "[2/10] Deploy do serviço da API e LoadBalancer..."
kubectl apply -f 01-api-service.yaml
kubectl apply -f 02-loadbalancer.yaml

show_step "[3/10] Aguardando LoadBalancer obter External IP..."
# Aguardar até 5 minutos pelo LoadBalancer
LOADBALANCER_URL=""
for i in {1..30}; do
    LOADBALANCER_URL=$(kubectl get svc fastfood-api-loadbalancer -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [ ! -z "$LOADBALANCER_URL" ]; then
        echo "✅ LoadBalancer pronto: $LOADBALANCER_URL"
        break
    fi
    echo "Aguardando LoadBalancer... tentativa $i/30"
    sleep 10
done

if [ -z "$LOADBALANCER_URL" ]; then
    echo "⚠️  LoadBalancer ainda não tem External IP. Usando valor existente..."
    LOADBALANCER_URL="a7a9258de2e8b4c638f8214ce6360ffc-609270677.us-east-1.elb.amazonaws.com"
fi

show_step "[4/10] Aplicando ConfigMap com RDS endpoint e URL dinâmica..."
# Exportar variáveis para envsubst
export LOADBALANCER_URL="$LOADBALANCER_URL"
export RDS_ENDPOINT="$RDS_ENDPOINT"

echo "🔧 Variáveis de substituição:"
echo "   LOADBALANCER_URL: $LOADBALANCER_URL"
echo "   RDS_ENDPOINT: $RDS_ENDPOINT"

# Substituir variáveis e aplicar
envsubst < 03-config.yaml | kubectl apply -f -

show_step "[5/10] Deploy da API..."
# Exportar variáveis para API
export ECR_URI="$ECR_URI"
export IMAGE_TAG="latest"

echo "🔧 DATABASE_URL que será usada: mysql://admin:admin123@$RDS_ENDPOINT:3306/fastfood?allowPublicKeyRetrieval=true"

# Substituir variáveis e aplicar
envsubst < 04-api-deployment.yaml | kubectl apply -f -

show_step "[6/10] Verificando se precisa reiniciar deployments..."
if kubectl get deployment fastfood-api >/dev/null 2>&1 && [ "$(kubectl get deployment fastfood-api -o jsonpath='{.status.replicas}')" -gt 0 ]; then
    echo "Deployment já existe - forçando restart para pegar nova imagem e configs..."
    kubectl rollout restart deployment/fastfood-api
    kubectl rollout status deployment/fastfood-api --timeout=300s
else
    echo "Primeiro deploy detectado - aguardando pods ficarem prontos..."
    kubectl wait --for=condition=Ready pod -l app=fastfood-api --timeout=300s
fi

show_step "[7/10] Executando migrations do banco de dados no RDS..."
API_POD=$(kubectl get pods -l app=fastfood-api -o jsonpath="{.items[0].metadata.name}")
kubectl exec $API_POD -- npx prisma migrate deploy
echo "Migrations executadas com sucesso no RDS!"

show_step "[8/10] Instalando Metrics Server oficial..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

show_step "[9/10] Aguardando Metrics Server ficar pronto..."
kubectl wait --for=condition=Ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s

show_step "[10/10] Aplicando HPA (Horizontal Pod Autoscaler)..."
kubectl apply -f 05-hpa.yaml

echo ""
echo "[✅] Deploy finalizado com sucesso!"
echo ""
kubectl get pods
kubectl get svc
kubectl get hpa
