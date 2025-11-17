# 🔧 Guia de Troubleshooting - SalonTime

Soluções para problemas comuns durante instalação e operação.

## 📋 Índice Rápido

- [Problemas de Instalação](#problemas-de-instalação)
- [Problemas de Conectividade](#problemas-de-conectividade)
- [Problemas com Containers](#problemas-com-containers)
- [Problemas com Banco de Dados](#problemas-com-banco-de-dados)
- [Problemas de Performance](#problemas-de-performance)
- [Comandos Úteis](#comandos-úteis)

## Problemas de Instalação

### ❌ Erro: "AWS CLI not found"

**Sintoma:**
```
✗ AWS CLI not found. Please install AWS CLI v2.
```

**Solução:**

Linux:
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

macOS:
```bash
brew install awscli
```

Verifique:
```bash
aws --version
```

### ❌ Erro: "AWS credentials not configured"

**Sintoma:**
```
✗ AWS credentials not configured. Run 'aws configure' first.
```

**Solução:**
```bash
aws configure
```

Forneça:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (ex: us-east-1)
- Output format: json

Teste:
```bash
aws sts get-caller-identity
```

### ❌ Erro: "jq not found"

**Sintoma:**
```
install-salontime.sh: line 42: jq: command not found
```

**Solução:**

Linux:
```bash
sudo yum install -y jq  # Amazon Linux/RHEL
sudo apt-get install -y jq  # Debian/Ubuntu
```

macOS:
```bash
brew install jq
```

### ❌ Erro: "SSH key not found"

**Sintoma:**
```
✗ SSH key not found: /path/to/key.pem
```

**Solução:**

1. Crie key pair na AWS:
```bash
aws ec2 create-key-pair \
  --key-name salontime-key \
  --query 'KeyMaterial' \
  --output text > salontime-key.pem
chmod 600 salontime-key.pem
```

2. Atualize `.env`:
```bash
KEY_PAIR_NAME=salontime-key
KEY_FILE_PATH=/caminho/completo/salontime-key.pem
```

### ❌ Erro: "VPC limit exceeded"

**Sintoma:**
```
An error occurred (VpcLimitExceeded)
```

**Solução:**

1. Liste VPCs existentes:
```bash
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]'
```

2. Delete VPCs não usadas ou solicite aumento de limite via AWS Support.

### ❌ Instalação trava em "Creating NAT Gateway"

**Sintoma:**
Instalação para em "Waiting for NAT Gateway..."

**Solução:**

NAT Gateway pode levar 3-5 minutos. Se passar de 10 minutos:

1. Verifique no console AWS
2. Veja logs detalhados:
```bash
tail -f logs/salontime-*.log
```

3. Se realmente travou, cancele (Ctrl+C) e:
```bash
./scripts/destroy-all.sh
./install-salontime.sh
```

## Problemas de Conectividade

### ❌ Não consigo acessar o ALB

**Sintoma:**
Timeout ao acessar URL do ALB

**Diagnóstico:**
```bash
# Obter DNS do ALB
ALB_DNS=$(jq -r '.alb_dns' state.json)
echo $ALB_DNS

# Testar conectividade
curl -I http://$ALB_DNS
```

**Soluções:**

1. **Security Group:** Verifique regras inbound do ALB SG
```bash
ALB_SG=$(jq -r '.alb_sg_id' state.json)
aws ec2 describe-security-groups --group-ids $ALB_SG
```

2. **Target Health:** Verifique saúde dos targets
```bash
./scripts/10-health-check.sh
```

3. **Aguarde propagação DNS:** Pode levar 2-5 minutos

### ❌ ALB retorna 503 Service Unavailable

**Sintoma:**
```
HTTP/1.1 503 Service Temporarily Unavailable
```

**Diagnóstico:**
```bash
# Verificar target health
FRONTEND_TG=$(jq -r '.frontend_tg_arn' state.json)
aws elbv2 describe-target-health --target-group-arn $FRONTEND_TG
```

**Possíveis Causas:**

1. **Containers não rodando:**
```bash
FRONTEND_IP=$(jq -r '.frontend_public_ip' state.json)
ssh -i $KEY_FILE_PATH ec2-user@$FRONTEND_IP "docker ps"
```

2. **Health check path incorreto:**
Verifique se o path existe na aplicação

3. **Port mismatch:**
Verifique se o container expõe a porta correta

**Solução:**
```bash
# Reiniciar containers
ssh -i $KEY_FILE_PATH ec2-user@$FRONTEND_IP "docker-compose restart"
```

### ❌ Não consigo fazer SSH nas instâncias

**Sintoma:**
```
ssh: connect to host X.X.X.X port 22: Connection timed out
```

**Soluções:**

1. **Verifique Security Group:**
```bash
EC2_SG=$(jq -r '.ec2_sg_id' state.json)
aws ec2 describe-security-groups --group-ids $EC2_SG
```

Deve ter regra SSH (22) do seu IP.

2. **Atualize SSH_ALLOWED_CIDR no .env:**
```bash
# Descubra seu IP público
curl https://ifconfig.me

# Atualize .env
SSH_ALLOWED_CIDR=SEU.IP.AQUI/32
```

3. **Verifique permissões da chave:**
```bash
chmod 600 /caminho/para/chave.pem
```

## Problemas com Containers

### ❌ Container não inicia

**Diagnóstico:**
```bash
ssh -i $KEY_FILE_PATH ec2-user@$INSTANCE_IP

# Ver containers
docker ps -a

# Ver logs
docker logs <container-name>
```

**Possíveis Causas:**

1. **Erro no build:**
```bash
docker images
# Se imagem não existe, rebuild
docker-compose up -d --build
```

2. **Porta em uso:**
```bash
sudo netstat -tlnp | grep :3000
```

3. **Falta de memória:**
```bash
free -h
docker stats
```

**Solução Geral:**
```bash
# Reconstruir do zero
docker-compose down
docker system prune -af
docker-compose up -d --build
```

### ❌ Build do frontend falha

**Sintoma:**
```
ERROR: failed to solve: process "/bin/sh -c npm run build" did not complete successfully
```

**Solução:**

1. **Clone manual para debug:**
```bash
git clone https://github.com/Grupo1-Semestre3/salontime-front-end-react
cd salontime-front-end-react
npm install
npm run build
```

2. **Verifique Node version:**
```bash
node --version  # Deve ser 18.x
```

3. **Aumente timeout do Docker:**
```bash
# Em docker-compose.yml, adicione:
build:
  args:
    BUILDKIT_PROGRESS: plain
```

### ❌ Build do backend falha

**Sintoma:**
```
BUILD FAILED in 2m 15s
```

**Solução:**

1. **Verifique Java version:**
```bash
java -version  # Deve ser 17
```

2. **Clone e teste localmente:**
```bash
git clone https://github.com/Grupo1-Semestre3/salontime-app-kotlin
cd salontime-app-kotlin
./gradlew clean build
```

3. **Aumente memória do Docker:**
```bash
# Editar /etc/docker/daemon.json
{
  "default-runtime": "runc",
  "storage-driver": "overlay2"
}
```

## Problemas com Banco de Dados

### ❌ Backend não conecta ao RDS

**Sintoma:**
Logs mostram:
```
Communications link failure
```

**Diagnóstico:**
```bash
# Obter endpoint do RDS
DB_ENDPOINT=$(jq -r '.db_endpoint' state.json)
echo $DB_ENDPOINT

# Testar do EC2 backend
BACKEND_IP=$(jq -r '.backend_public_ip' state.json)
ssh -i $KEY_FILE_PATH ec2-user@$BACKEND_IP

# Dentro da instância:
telnet $DB_ENDPOINT 3306
```

**Soluções:**

1. **Security Group:** Verifique se RDS SG permite tráfego do EC2 SG
```bash
RDS_SG=$(jq -r '.rds_sg_id' state.json)
aws ec2 describe-security-groups --group-ids $RDS_SG
```

2. **Credenciais:** Verifique application.properties
```bash
ssh -i $KEY_FILE_PATH ec2-user@$BACKEND_IP
cat /home/ec2-user/application.properties
```

3. **RDS Status:** Verifique se está "available"
```bash
DB_ID=$(jq -r '.db_identifier' state.json)
aws rds describe-db-instances --db-instance-identifier $DB_ID
```

### ❌ RDS provisionamento falha

**Sintoma:**
```
An error occurred (DBInstanceAlreadyExists)
```

**Solução:**

1. **Conflito de nome:** Mude PROJECT_NAME no .env
2. **Ou delete instância existente:**
```bash
aws rds delete-db-instance \
  --db-instance-identifier salontime-db \
  --skip-final-snapshot
```

### ❌ Não consigo executar SQL scripts

**Problema:**
Scripts SQL não executam automaticamente

**Solução Manual:**

1. **Criar bastion host ou usar EC2 backend:**
```bash
# Instalar MySQL client no EC2
ssh -i $KEY_FILE_PATH ec2-user@$BACKEND_IP
sudo yum install -y mysql

# Conectar ao RDS
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME

# Executar scripts
mysql -h $DB_ENDPOINT -u $DB_USERNAME -p$DB_PASSWORD $DB_NAME < criacao_bd.sql
```

## Problemas de Performance

### ❌ Aplicação lenta

**Diagnóstico:**

1. **CPU:**
```bash
ssh -i $KEY_FILE_PATH ec2-user@$INSTANCE_IP
top
```

2. **Memória:**
```bash
free -h
docker stats
```

3. **Disco:**
```bash
df -h
```

**Soluções:**

1. **Upgrade instance type:**
```bash
# No .env
FRONTEND_INSTANCE_TYPE=t3.large
BACKEND_INSTANCE_TYPE=t3.large
```

2. **Otimizar containers:**
- Reduzir log verbosity
- Habilitar cache
- Otimizar queries

### ❌ RDS com alta latência

**Diagnóstico:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBInstanceIdentifier,Value=$DB_ID \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

**Soluções:**
- Upgrade RDS instance class
- Adicionar Read Replicas
- Otimizar queries (indexes)

## Comandos Úteis

### Verificações Rápidas

```bash
# Status geral
./scripts/10-health-check.sh

# Ver todos os recursos
cat state.json | jq

# Ver logs de instalação
tail -100 logs/salontime-*.log

# Listar todas as instâncias
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=SalonTime" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PublicIpAddress]'
```

### Debug de Containers

```bash
# Em cada EC2
ssh -i $KEY_FILE_PATH ec2-user@$IP

# Status
docker ps -a

# Logs
docker logs -f --tail 100 <container>

# Entrar no container
docker exec -it <container> sh

# Restart
docker restart <container>

# Rebuild
docker-compose up -d --build --force-recreate
```

### Debug de Rede

```bash
# Test ALB
curl -I http://$ALB_DNS

# Test direct EC2
curl -I http://$EC2_IP:3000

# Test de dentro do EC2
ssh -i $KEY_FILE_PATH ec2-user@$IP
curl localhost:3000
```

### Limpeza

```bash
# Remover containers órfãos
docker container prune -f

# Remover imagens não usadas
docker image prune -af

# Remover volumes
docker volume prune -f

# Limpeza total
docker system prune -af --volumes
```

## 🆘 Quando Tudo Falhar

### Destruir e Reinstalar

```bash
# 1. Destruir tudo
./scripts/destroy-all.sh

# 2. Aguardar 5-10 minutos

# 3. Verificar se tudo foi removido
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=SalonTime"

# 4. Reinstalar do zero
./install-salontime.sh
```

### Coleta de Informações para Suporte

```bash
# Criar arquivo de debug
cat > debug-info.txt << EOF
=== Environment ===
$(cat .env)

=== State ===
$(cat state.json)

=== Health Check ===
$(./scripts/10-health-check.sh)

=== Logs (last 100 lines) ===
$(tail -100 logs/salontime-*.log)

=== AWS Resources ===
$(aws ec2 describe-instances --filters "Name=tag:Project,Values=SalonTime")
EOF

# Compartilhar debug-info.txt (remova senhas antes!)
```

## 📞 Obter Ajuda

1. 📖 Consulte [FAQ](FAQ.md)
2. 📚 Revise [Documentação](../README.md)
3. 💬 Abra issue no GitHub com debug-info.txt

---

**Problema não resolvido? Abra uma issue com detalhes!**
