# ⚡ Guia de Instalação Rápida - SalonTime

Instale o sistema completo SalonTime na AWS em 3 comandos.

## ⏱️ Tempo Estimado: 35-45 minutos

## 📋 Pré-requisitos

Antes de iniciar, certifique-se de ter:

- ✅ AWS CLI v2.x instalado e configurado (`aws configure`)
- ✅ jq instalado (`sudo yum install jq` ou `brew install jq`)
- ✅ Git instalado
- ✅ Par de chaves SSH criado na região AWS desejada
- ✅ Permissões AWS adequadas (EC2, RDS, VPC, ELB, WAF)

## 🚀 Instalação em 3 Passos

### Passo 1: Clonar o Repositório

```bash
git clone https://github.com/Grupo1-Semestre3/salontime-infrastructure.git
cd salontime-infrastructure
```

### Passo 2: Configurar Ambiente

Execute o wizard interativo de configuração:

```bash
./configure.sh
```

O wizard irá perguntar:
- Região AWS
- Configurações de rede (VPC, subnets)
- Tipos de instância EC2
- Configurações do banco de dados
- Senhas e credenciais

**Dica:** Para produção, use as configurações padrão. Para dev/test, use instâncias menores.

### Passo 3: Executar Instalação

```bash
./install-salontime.sh
```

O script irá:
1. Verificar pré-requisitos
2. Criar VPC e rede
3. Configurar security groups
4. Provisionar RDS MySQL
5. Criar 3 instâncias EC2
6. Fazer deploy dos containers
7. Configurar Load Balancer
8. Ativar AWS WAF
9. Executar health check

## ✅ Verificação

Ao final, você verá:

```
=========================================
     Installation Complete!
=========================================

✓ SalonTime infrastructure deployed successfully!

Duration: 42m 15s

>>> Access Information

ℹ Application Load Balancer: http://salontime-alb-123456789.us-east-1.elb.amazonaws.com
ℹ Frontend: http://salontime-alb-123456789.us-east-1.elb.amazonaws.com/
ℹ Backend API: http://salontime-alb-123456789.us-east-1.elb.amazonaws.com/api/
ℹ BotPress: http://salontime-alb-123456789.us-east-1.elb.amazonaws.com/bot/
```

## 🔍 Próximos Passos

### 1. Testar Acesso

```bash
# Executar health check
./scripts/10-health-check.sh
```

### 2. Verificar Aplicações

Acesse cada URL no navegador:
- Frontend: interface do usuário
- Backend: API REST (retorna JSON)
- BotPress: interface do chatbot

### 3. Revisar Logs

```bash
# Ver log da instalação
tail -f logs/salontime-*.log
```

## 🔧 Operações Comuns

### Atualizar Aplicação

```bash
# Atualizar frontend
./scripts/update-frontend.sh

# Atualizar backend
./scripts/update-backend.sh

# Atualizar botpress
./scripts/update-botpress.sh
```

### Fazer Rollback

```bash
# Voltar para versão anterior
./scripts/rollback-frontend.sh
```

### Destruir Infraestrutura

```bash
# Remover todos os recursos (requer confirmação dupla)
./scripts/destroy-all.sh
```

## 🐛 Problemas?

Se algo der errado:

1. Verifique o log: `cat logs/salontime-*.log`
2. Execute health check: `./scripts/10-health-check.sh`
3. Consulte: [Troubleshooting Guide](TROUBLESHOOTING.md)
4. Abra uma issue no GitHub

## 💡 Dicas

### Para Desenvolvimento
```bash
# No configure.sh, escolha:
# - Instâncias t3.small
# - RDS db.t3.micro Single-AZ
# - Desabilitar WAF
# Custo: ~$125/mês
```

### Para Produção
```bash
# Use configurações padrão:
# - Instâncias t3.medium
# - RDS db.t3.medium Multi-AZ
# - WAF habilitado
# Custo: ~$322/mês
```

## 📞 Suporte

- 📖 [Documentação Completa](../README.md)
- ❓ [FAQ](FAQ.md)
- 🔧 [Troubleshooting](TROUBLESHOOTING.md)

---

**Pronto para começar? Execute `./configure.sh` agora!**
