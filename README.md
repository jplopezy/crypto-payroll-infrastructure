# Crypto Payroll API - DevSecOps Infrastructure

## Overview

This repository contains the secure infrastructure and CI/CD pipeline for a crypto payroll microservice built for BAX. The service handles encrypted payroll files, processes wallet addresses and amounts, and integrates with external signing APIs while maintaining security best practices.

## Architecture

### Infrastructure Components

- **VPC**: Custom Virtual Private Cloud with public and private subnets
- **Compute**: ECS Fargate cluster for scalable containerized backend
- **Storage**: S3 bucket with encryption, versioning, and access logging
- **Security**: IAM roles with least-privilege access principles
- **Secrets**: AWS Secrets Manager for secure API key storage
- **Monitoring**: CloudWatch logs and metrics

### Security Features

- Network isolation with private subnets
- Encryption at rest and in transit
- Least-privilege IAM policies
- Secure secret management
- Automated security scanning in CI/CD
- VPC endpoints for AWS services

## Key Decisions

1. **ECS Fargate over EC2**: Better security posture with managed infrastructure
2. **Private subnets**: Backend services isolated from public internet
3. **Application Load Balancer**: Secure entry point with SSL termination
4. **Secrets Manager**: Centralized secret management with automatic rotation
5. **Multi-AZ deployment**: High availability across availability zones

## Assumptions

- External signing API (Fireblocks-like) requires API key authentication
- Payroll files are encrypted before upload
- S3 bucket will store transaction logs and processed files
- Service will scale based on demand (auto-scaling configured)
- Compliance requirements for financial data handling

## Smart Contract Extension

If this service were extended to deploy smart contracts (employee vesting contracts, programmable payouts):

### Infrastructure Adaptations

1. **Additional ECS Services**: Separate services for contract deployment and verification
2. **Enhanced IAM Roles**: Granular permissions for different contract operations
3. **Multi-signature Support**: Integration with hardware security modules (HSM)
4. **Blockchain Monitoring**: CloudWatch integration with blockchain events
5. **Gas Management**: Automated gas price optimization and transaction retry logic

### CI/CD Enhancements

1. **Contract Verification**: Automated smart contract verification on deployment
2. **Security Audits**: Integration with static analysis tools (Slither, Mythril)
3. **Multi-stage Deployments**: Testnet → Staging → Mainnet deployment pipeline
4. **Signer Separation**: Different deployment keys for different environments
5. **Rollback Capabilities**: Automated contract upgrade and rollback mechanisms

## Getting Started

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform v1.0+
- Docker v20.0+
- Node.js v18+ (for local development)

### Quick Deployment
```bash
# Clone the repository
git clone https://github.com/jplopezy/crypto-payroll-infrastructure.git
cd crypto-payroll-infrastructure

# Configure environment
cp env.example .env
# Edit .env with your configuration

# Deploy infrastructure
chmod +x deploy.sh
./deploy.sh dev
```

### Manual Deployment
```bash
# 1. Deploy infrastructure
cd terraform
terraform init
terraform workspace new dev
terraform plan -var="environment=dev"
terraform apply

# 2. Configure secrets
aws secretsmanager update-secret \
  --secret-id crypto-payroll/external-signing-api-key \
  --secret-string '{"api_key":"your-api-key"}'

# 3. Build and deploy application
docker build -t crypto-payroll-api ./src
# Push to ECR and update ECS service
```

### Local Development
```bash
# Using Docker Compose
docker-compose up -d

# Or manual setup
cd src
npm install
npm run dev
```

For detailed instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)

## Security Considerations

- All secrets are stored in AWS Secrets Manager
- Network traffic is encrypted using TLS
- Access logging is enabled on all S3 buckets
- IAM policies follow least-privilege principles
- Regular security scans are performed in CI/CD pipeline

## Project Structure

```
crypto-payroll-infrastructure/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output values
│   ├── vpc.tf                # VPC and networking
│   ├── ecs.tf                # ECS cluster and services
│   ├── s3.tf                 # S3 buckets and policies
│   ├── iam.tf                # IAM roles and policies
│   └── secrets.tf            # Secrets Manager configuration
├── .github/workflows/        # CI/CD pipelines
│   ├── deploy.yml            # Main deployment pipeline
│   └── security-scan.yml     # Security scanning pipeline
├── docs/                     # Documentation
│   └── wallet-auth.md        # Wallet authentication flow
├── src/                      # Application source code
│   └── Dockerfile            # Container configuration
└── README.md                 # This file
```
"# Security fixes applied" 
"# Security scan trigger - $(Get-Date)" 
"Updated: $(Get-Date)"  
