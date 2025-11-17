# 🚀 SalonTime AWS Infrastructure Automation

Complete automated installation and management of the SalonTime system on AWS using Shell Script + AWS CLI + Docker.

**Transforms 4-6 hours of manual work into 35-45 minutes of automated deployment.**

## 📋 Overview

This repository provides complete automation for deploying the SalonTime system on AWS, including:

- ✅ **VPC and Network Infrastructure** - Fully isolated network with public/private subnets
- ✅ **Application Load Balancer** - Path-based routing with health checks
- ✅ **3 EC2 Instances** - Separate instances for Frontend, Backend, and BotPress
- ✅ **RDS MySQL Database** - Multi-AZ with automated backups
- ✅ **AWS WAF** - OWASP Top 10 protection and rate limiting
- ✅ **Docker Containers** - Automated deployment of all applications
- ✅ **Complete Management** - Update, rollback, and health check scripts

## 🎯 Features

### Infrastructure Automation
- One-command installation and configuration
- Idempotent scripts (safe to re-run)
- State management for resource tracking
- Automatic cleanup and resource destruction

### Application Deployment
- Automated Docker container builds
- Database schema initialization
- Environment variable configuration
- Health monitoring and status checks

### Operations Support
- Individual component updates
- Rollback with automatic backup
- Comprehensive health checks
- Detailed logging and troubleshooting

## 🚀 Quick Start

### Prerequisites

- AWS CLI v2.x installed and configured
- jq (JSON processor)
- Git
- SSH key pair created in your AWS region
- Bash shell (Linux/macOS)

### Installation in 3 Steps

```bash
# 1. Clone the repository
git clone https://github.com/Grupo1-Semestre3/salontime-infrastructure.git
cd salontime-infrastructure

# 2. Configure environment (interactive wizard)
./configure.sh

# 3. Deploy infrastructure
./install-salontime.sh
```

**Total Time:** 35-45 minutes ⏱️

## 📁 Project Structure

```
salontime-infrastructure/
├── README.md                    # This file
├── configure.sh                 # Interactive configuration wizard
├── install-salontime.sh         # Main installation orchestrator
├── .env.example                 # Environment variables template
├── .gitignore                   # Git exclusions
│
├── scripts/                     # Modular installation scripts
│   ├── 01-setup-vpc.sh
│   ├── 02-setup-security-groups.sh
│   ├── 03-setup-rds.sh
│   ├── 04-create-ec2-instances.sh
│   ├── 05-deploy-frontend.sh
│   ├── 06-deploy-backend.sh
│   ├── 07-deploy-botpress.sh
│   ├── 08-setup-loadbalancer.sh
│   ├── 09-setup-waf.sh
│   ├── 10-health-check.sh
│   ├── update-frontend.sh
│   ├── update-backend.sh
│   ├── update-botpress.sh
│   ├── rollback-frontend.sh
│   ├── rollback-backend.sh
│   ├── rollback-botpress.sh
│   └── destroy-all.sh
│
├── utils/                       # Utility functions
│   ├── colors.sh               # Terminal colors and formatting
│   ├── logger.sh               # Dual logging (terminal + file)
│   ├── validators.sh           # Input validation functions
│   ├── aws-helpers.sh          # AWS CLI helpers with retry
│   └── ssh-helpers.sh          # SSH and remote execution
│
├── docker/                      # Docker configurations
│   ├── frontend/
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   └── docker-compose.yml
│   ├── backend/
│   │   ├── Dockerfile
│   │   ├── application.properties.template
│   │   └── docker-compose.yml
│   └── botpress/
│       ├── Dockerfile
│       ├── botpress.config.json
│       └── docker-compose.yml
│
└── docs/                        # Documentation
    ├── INSTALACAO-RAPIDA.md
    ├── ARQUITETURA.md
    ├── FAQ.md
    └── TROUBLESHOOTING.md
```

## 🏗️ Architecture

```
                        INTERNET
                           │
                           ▼
                    ┌─────────────┐
                    │   AWS WAF   │
                    └──────┬──────┘
                           │
                ┌──────────▼──────────┐
                │  Load Balancer      │
                │  / → Frontend        │
                │  /api/* → Backend    │
                │  /bot/* → BotPress   │
                └─┬────────┬─────────┬┘
                  │        │         │
         ┌────────┘        │         └────────┐
         │                 │                  │
    ┌────▼────┐      ┌─────▼─────┐      ┌────▼────┐
    │ EC2     │      │ EC2       │      │ EC2     │
    │ Frontend│      │ Backend   │      │ BotPress│
    │ React   │      │ Kotlin    │      │ Chatbot │
    │ :3000   │      │ :8080     │      │ :8081   │
    └─────────┘      └─────┬─────┘      └─────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ RDS MySQL   │
                    │ Multi-AZ    │
                    │ :3306       │
                    └─────────────┘
```

## 📊 Components

| Component | Description | Configuration |
|-----------|-------------|---------------|
| VPC | Isolated network | 10.0.0.0/16 |
| Public Subnet | Frontend access | 10.0.1.0/24 |
| Private Subnets | Backend & Database | 10.0.2.0/24, 10.0.3.0/24 |
| EC2 Instances | 3x t3.medium | Amazon Linux 2 |
| RDS MySQL | db.t3.medium | Multi-AZ, v8.0 |
| Load Balancer | Application LB | Internet-facing |
| WAF | Web ACL | OWASP rules + rate limit |

## 💰 Cost Estimate

### Production Environment
- EC2 (3x t3.medium): ~$90/month
- RDS (db.t3.medium Multi-AZ): ~$120/month
- ALB: ~$25/month
- NAT Gateway: ~$35/month
- WAF: ~$15/month
- Data Transfer & CloudWatch: ~$37/month
- **TOTAL: ~$322/month**

### Development Environment (Optimized)
- EC2 (3x t3.small): ~$45/month
- RDS (db.t3.micro Single-AZ): ~$13/month
- ALB: ~$25/month
- NAT Gateway: ~$35/month
- Other: ~$7/month
- **TOTAL: ~$125/month** (60% savings)

## 🔧 Operations

### Update Applications

```bash
# Update individual components
./scripts/update-frontend.sh
./scripts/update-backend.sh
./scripts/update-botpress.sh
```

### Rollback

```bash
# Rollback to previous version (with backup)
./scripts/rollback-frontend.sh
./scripts/rollback-backend.sh
./scripts/rollback-botpress.sh
```

### Health Check

```bash
# Run comprehensive health check
./scripts/10-health-check.sh
```

### Destroy Infrastructure

```bash
# Complete cleanup (requires double confirmation)
./scripts/destroy-all.sh
```

## 📚 Documentation

- [Quick Installation Guide](docs/INSTALACAO-RAPIDA.md) - Step-by-step installation
- [Architecture Details](docs/ARQUITETURA.md) - System architecture and design
- [FAQ](docs/FAQ.md) - Frequently asked questions
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🔒 Security

- AWS WAF with OWASP Top 10 protection
- Rate limiting (2000 requests per 5 minutes)
- Private subnets for applications and database
- Security groups with least privilege
- RDS encryption at rest
- No hardcoded credentials

## 🧪 Testing

All scripts have been tested for:
- ✅ Idempotency (safe to re-run)
- ✅ Error handling and rollback
- ✅ Resource cleanup
- ✅ Connectivity and health
- ✅ Update and rollback procedures

## 📝 Logs

Logs are automatically saved to `logs/` directory with rotation (keeps last 10).

View current log:
```bash
tail -f logs/salontime-*.log
```

## 🤝 Contributing

This is a project for Grupo1-Semestre3. For contributions:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📞 Support

For issues or questions:
- Open an issue on GitHub
- Check the [FAQ](docs/FAQ.md)
- Review [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## 📄 License

This project is part of the SalonTime system developed by Grupo1-Semestre3.

## 🎓 Related Repositories

- [Frontend](https://github.com/Grupo1-Semestre3/salontime-front-end-react) - React + Vite
- [Backend](https://github.com/Grupo1-Semestre3/salontime-app-kotlin) - Spring Boot + Kotlin
- [Database](https://github.com/Grupo1-Semestre3/salontime-banco-dados) - MySQL Scripts
- [BotPress](https://github.com/Grupo1-Semestre3/salontime-bot-atendimento) - Chatbot

## ⭐ Acknowledgments

Built with:
- AWS CLI
- Docker & Docker Compose
- Shell Script
- jq (JSON processor)

---

**Made with ❤️ by Grupo1-Semestre3**
