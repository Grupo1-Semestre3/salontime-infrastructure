# 🏗️ Arquitetura do Sistema SalonTime

Documentação detalhada da arquitetura e design da infraestrutura AWS.

## 📐 Visão Geral

O sistema SalonTime utiliza uma arquitetura de 3 camadas na AWS:

1. **Camada de Apresentação** - Frontend React
2. **Camada de Aplicação** - Backend Spring Boot/Kotlin + BotPress
3. **Camada de Dados** - MySQL RDS

## 🌐 Diagrama de Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                         INTERNET                            │
└────────────────────────┬────────────────────────────────────┘
                         │
                         │ HTTPS/HTTP
                         │
              ┌──────────▼──────────┐
              │     AWS WAF         │
              │  - Rate Limiting    │
              │  - OWASP Rules      │
              └──────────┬──────────┘
                         │
          ┌──────────────▼─────────────────┐
          │  Application Load Balancer     │
          │  - Path-based Routing          │
          │  - Health Checks               │
          │  - Sticky Sessions             │
          └───┬──────────┬──────────┬──────┘
              │          │          │
    ┌─────────┘          │          └─────────┐
    │                    │                    │
    │  VPC: 10.0.0.0/16  │                    │
    │                    │                    │
┌───▼────────┐  ┌────────▼───────┐  ┌────────▼───────┐
│Public Subnet│  │Public Subnet   │  │Public Subnet   │
│10.0.1.0/24  │  │10.0.1.0/24     │  │10.0.1.0/24     │
│             │  │                │  │                │
│ EC2-Front   │  │ EC2-Backend    │  │ EC2-BotPress   │
│ React+Vite  │  │ Spring+Kotlin  │  │ BotPress       │
│ Nginx :80   │  │ Java :8080     │  │ Node :3000     │
│ Docker      │  │ Docker         │  │ Docker         │
└─────────────┘  └────────┬───────┘  └────────────────┘
                          │
                          │ JDBC :3306
                          │
            ┌─────────────▼────────────────┐
            │   Private Subnets            │
            │   10.0.2.0/24, 10.0.3.0/24   │
            │                              │
            │   ┌──────────────────┐       │
            │   │  RDS MySQL 8.0   │       │
            │   │  Multi-AZ        │       │
            │   │  Automated Backup│       │
            │   └──────────────────┘       │
            └──────────────────────────────┘
```

## 🔧 Componentes Detalhados

### 1. VPC (Virtual Private Cloud)

**CIDR:** 10.0.0.0/16

**Componentes:**
- 1x Public Subnet (10.0.1.0/24) - AZ1
- 2x Private Subnets (10.0.2.0/24, 10.0.3.0/24) - AZ1, AZ2
- Internet Gateway para acesso externo
- NAT Gateway para saída de privadas
- Route Tables customizadas

### 2. Security Groups

#### ALB Security Group
- **Inbound:**
  - HTTP (80) de 0.0.0.0/0
  - HTTPS (443) de 0.0.0.0/0
- **Outbound:**
  - Todas as portas para EC2 SG

#### EC2 Security Group
- **Inbound:**
  - SSH (22) de IP configurado
  - 3000 do ALB SG (Frontend)
  - 8080 do ALB SG (Backend)
  - 8081 do ALB SG (BotPress)
- **Outbound:**
  - Todas as portas

#### RDS Security Group
- **Inbound:**
  - MySQL (3306) do EC2 SG
- **Outbound:**
  - Nenhuma

### 3. Application Load Balancer

**Tipo:** Application Load Balancer (Layer 7)

**Listeners:**
- HTTP:80

**Roteamento:**
```
/ (default)     → Frontend Target Group (EC2:3000)
/api/*          → Backend Target Group (EC2:8080)
/bot/*          → BotPress Target Group (EC2:8081)
```

**Health Checks:**
- Frontend: GET / → 200 OK
- Backend: GET /actuator/health → 200 OK
- BotPress: GET / → 200 OK

**Configuração:**
- Intervalo: 30s
- Timeout: 5s
- Healthy: 2 checks
- Unhealthy: 3 checks

### 4. AWS WAF

**Regras Implementadas:**

1. **Rate Limiting**
   - Limite: 2000 requisições / 5 minutos por IP
   - Ação: Block

2. **AWS Managed Rules - Core Rule Set**
   - Proteção contra OWASP Top 10
   - SQL Injection
   - Cross-Site Scripting (XSS)
   - Local File Inclusion (LFI)

### 5. EC2 Instances

#### Especificações Padrão (Produção)
- **Tipo:** t3.medium (2 vCPU, 4GB RAM)
- **AMI:** Amazon Linux 2
- **Storage:** 20GB gp3
- **Software:**
  - Docker
  - Docker Compose
  - AWS CLI

#### Frontend Instance
- **Aplicação:** React 18 + Vite
- **Web Server:** Nginx
- **Porta:** 3000
- **Build:** Multi-stage Dockerfile

#### Backend Instance
- **Aplicação:** Spring Boot 3 + Kotlin
- **Runtime:** OpenJDK 17
- **Porta:** 8080
- **Build:** Gradle

#### BotPress Instance
- **Aplicação:** BotPress v12
- **Runtime:** Node.js
- **Porta:** 8081

### 6. RDS MySQL

**Configuração Produção:**
- **Engine:** MySQL 8.0
- **Instance Class:** db.t3.medium
- **Storage:** 20GB gp3 (auto-scaling até 100GB)
- **Multi-AZ:** Sim (alta disponibilidade)
- **Backup:** 14 dias de retenção
- **Encryption:** At rest habilitado

**Configuração Dev:**
- **Instance Class:** db.t3.micro
- **Multi-AZ:** Não
- **Backup:** 7 dias

## 🔐 Segurança

### Camadas de Segurança

1. **AWS WAF** - Primeira linha de defesa
2. **Security Groups** - Firewall de instância
3. **Private Subnets** - Isolamento de banco
4. **IAM Roles** - Least privilege
5. **Encryption** - At rest e in transit

### Fluxo de Dados Seguro

```
Internet → WAF → ALB → Security Group → EC2 → Security Group → RDS
```

### Credenciais

- ✅ Senhas armazenadas em variáveis de ambiente
- ✅ Nunca commitadas no código
- ✅ SSH keys protegidas (chmod 600)
- ✅ RDS em subnet privada (sem acesso público)

## 📊 Escalabilidade

### Escalabilidade Horizontal

**Implementação Futura:**
- Auto Scaling Groups para EC2
- Read Replicas para RDS
- ElastiCache para caching

### Escalabilidade Vertical

**Atual:**
- Alterar instance types no .env
- Executar update scripts

## 🔄 Alta Disponibilidade

**Implementado:**
- ✅ RDS Multi-AZ (failover automático)
- ✅ ALB em múltiplas AZs
- ✅ Subnets em diferentes AZs

**Recomendado para Produção:**
- [ ] Auto Scaling (mínimo 2 instâncias por app)
- [ ] Route 53 Health Checks
- [ ] CloudWatch Alarms

## 📈 Monitoramento

### CloudWatch Metrics

**EC2:**
- CPU Utilization
- Network In/Out
- Disk I/O

**RDS:**
- Database Connections
- CPU Utilization
- Free Storage Space
- Read/Write IOPS

**ALB:**
- Request Count
- Target Response Time
- HTTP 4xx/5xx Errors
- Active Connections

### Logs

**Aplicação:**
- Frontend: Nginx access/error logs
- Backend: Spring Boot logs
- BotPress: Application logs

**Infraestrutura:**
- VPC Flow Logs
- CloudTrail
- WAF Logs

## 💰 Otimização de Custos

### Estratégias

1. **Right-sizing**
   - Monitorar uso real
   - Ajustar tipos de instância

2. **Reserved Instances**
   - 40-60% economia para cargas previsíveis

3. **Spot Instances**
   - Para ambientes de dev/test
   - Até 90% economia

4. **Auto-scaling**
   - Escalar down fora do horário de pico

## 🚀 Melhorias Futuras

### Short-term
- [ ] HTTPS/SSL com Certificate Manager
- [ ] Route 53 para domínio customizado
- [ ] CloudWatch Dashboard customizado

### Medium-term
- [ ] Auto Scaling Groups
- [ ] Redis/ElastiCache
- [ ] S3 para assets estáticos

### Long-term
- [ ] Migração para ECS/EKS
- [ ] CI/CD com CodePipeline
- [ ] Infrastructure as Code com Terraform/CDK

## 📚 Referências

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

---

**Arquitetura desenhada por Grupo1-Semestre3**
