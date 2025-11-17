# ❓ FAQ - Perguntas Frequentes

Respostas para as perguntas mais comuns sobre a infraestrutura SalonTime.

## 📋 Índice

- [Instalação](#instalação)
- [Configuração](#configuração)
- [Operações](#operações)
- [Custos](#custos)
- [Segurança](#segurança)
- [Troubleshooting](#troubleshooting)

## Instalação

### Quanto tempo leva a instalação completa?

Entre 35-45 minutos, dependendo da região AWS e da velocidade de provisionamento do RDS.

### Posso parar e continuar depois?

Não recomendado. O script deve ser executado do início ao fim. Se interrompido, você pode destruir os recursos parciais com `destroy-all.sh` e recomeçar.

### Preciso de conhecimento em AWS?

Conhecimento básico é recomendado, mas os scripts são automatizados. Você precisa saber:
- Configurar AWS CLI
- Criar um par de chaves SSH
- Entender conceitos básicos de VPC e EC2

### Funciona no Windows?

Parcialmente. Recomendamos usar WSL2 (Windows Subsystem for Linux) ou Git Bash. Alguns comandos podem precisar de adaptação.

## Configuração

### Posso usar minhas próprias configurações de rede?

Sim! Edite o arquivo `.env` antes de executar `install-salontime.sh`. O wizard `configure.sh` facilita isso.

### Como altero os tipos de instância?

No `.env`, modifique:
```bash
FRONTEND_INSTANCE_TYPE=t3.small
BACKEND_INSTANCE_TYPE=t3.small
BOTPRESS_INSTANCE_TYPE=t3.small
```

### Posso desabilitar o WAF para economizar?

Sim. No `.env`:
```bash
ENABLE_WAF=false
```

Economia: ~$15/mês

### Como uso minha própria key pair SSH?

Durante `configure.sh`, informe o nome e caminho da sua chave:
```
KEY_PAIR_NAME=minha-chave
KEY_FILE_PATH=/caminho/para/minha-chave.pem
```

## Operações

### Como atualizo apenas o frontend?

```bash
./scripts/update-frontend.sh
```

### Como faço rollback se algo der errado?

```bash
./scripts/rollback-frontend.sh
```

O script criará automaticamente backups antes de updates.

### Como verifico se tudo está funcionando?

```bash
./scripts/10-health-check.sh
```

### Como acesso os logs das aplicações?

SSH na instância:
```bash
ssh -i /caminho/chave.pem ec2-user@<IP-INSTANCIA>
docker logs frontend
docker logs backend
docker logs botpress
```

### Posso ter múltiplos ambientes (dev/staging/prod)?

Sim! Use `.env` diferentes:
```bash
# Renomear .env para .env.prod
mv .env .env.prod

# Criar novo .env para dev
./configure.sh

# Instalar com novo .env
./install-salontime.sh
```

## Custos

### Quanto custa rodar em produção?

Aproximadamente **$322/mês** com configurações padrão (Multi-AZ, t3.medium).

### Como reduzir custos para dev/test?

Use instâncias menores e Single-AZ no `.env`:
```bash
FRONTEND_INSTANCE_TYPE=t3.small
BACKEND_INSTANCE_TYPE=t3.small
BOTPRESS_INSTANCE_TYPE=t3.small
DB_INSTANCE_CLASS=db.t3.micro
DB_MULTI_AZ=false
ENABLE_WAF=false
```

Custo dev/test: **~$125/mês** (60% economia)

### Como vejo meu custo atual?

AWS Cost Explorer:
```bash
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"
```

### Posso usar Reserved Instances?

Sim! Para cargas de longo prazo (1-3 anos), Reserved Instances economizam 40-60%.

## Segurança

### É seguro expor o ALB na internet?

Sim. O AWS WAF protege contra ataques comuns (OWASP Top 10), e rate limiting previne DDoS.

### Como configuro HTTPS?

Você precisa:
1. Domínio registrado
2. Certificado SSL no ACM
3. Modificar listener do ALB para HTTPS

### Devo mudar a senha padrão do banco?

**Sim, imediatamente!** Durante `configure.sh`, use uma senha forte (min 12 chars, letras+números+símbolos).

### Como restrinjo acesso SSH?

No `.env`, configure seu IP:
```bash
SSH_ALLOWED_CIDR=seu.ip.aqui.0/32
```

### O banco está exposto na internet?

Não. O RDS está em subnets privadas, acessível apenas pelas instâncias EC2.

## Troubleshooting

### Erro: "AWS CLI not configured"

Execute:
```bash
aws configure
```

E forneça:
- Access Key ID
- Secret Access Key
- Default region
- Output format (json)

### Erro: "Key pair not found"

Crie uma key pair na região AWS:
```bash
aws ec2 create-key-pair --key-name minha-chave --query 'KeyMaterial' --output text > minha-chave.pem
chmod 600 minha-chave.pem
```

### Containers não iniciam

SSH na instância e verifique:
```bash
docker ps -a
docker logs <container-name>
```

Possíveis causas:
- Erro no build da imagem
- Problemas de rede
- Configuração errada de variáveis

### ALB retorna 503

Verifique Target Health:
```bash
aws elbv2 describe-target-health --target-group-arn <ARN>
```

Possíveis causas:
- Containers não estão rodando
- Health check path incorreto
- Firewall bloqueando tráfego

### RDS não conecta

Verifique:
1. Security Group permite tráfego do EC2
2. Endpoint está correto no `.env`
3. Credenciais estão corretas

### Health check falha

Execute novamente:
```bash
./scripts/10-health-check.sh
```

Alguns componentes podem demorar mais para iniciar (backend: até 2 min).

### Como destruo tudo e começo de novo?

```bash
./scripts/destroy-all.sh
```

Aguarde ~10 minutos, então execute novamente:
```bash
./install-salontime.sh
```

## Avançado

### Posso usar com Terraform?

Este projeto usa Shell + AWS CLI. Para Terraform, você precisará reescrever os scripts em HCL.

### Como integro com CI/CD?

Crie um pipeline que:
1. Faz build da aplicação
2. Cria imagem Docker
3. Faz push para registry
4. Executa `update-*.sh` nas instâncias

### Suporta Blue-Green deployment?

Não nativamente. Você precisaria:
- Criar 2 sets de Target Groups
- Alternar no ALB após deploy
- Requer modificação dos scripts

### Como adiciono mais instâncias?

Modifique `04-create-ec2-instances.sh` para criar mais instâncias e registre-as nos Target Groups.

### Posso usar ECS/EKS em vez de EC2?

Sim, mas requer reescrita dos deployment scripts. O conceito permanece o mesmo.

## 📞 Ainda tem dúvidas?

- 📖 Consulte a [Documentação Completa](../README.md)
- 🔧 Veja o [Guia de Troubleshooting](TROUBLESHOOTING.md)
- 💬 Abra uma issue no GitHub

---

**Não encontrou sua resposta? Abra uma issue!**
