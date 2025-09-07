# Deployment Instructions

## Prerequisites

Before deploying the Crypto Payroll API infrastructure, ensure you have the following installed and configured:

### Required Tools
- **AWS CLI** v2.0+ with configured credentials
- **Terraform** v1.0+
- **Docker** v20.0+
- **Git** v2.0+
- **Node.js** v18+ (for local development)

### AWS Configuration
1. Configure AWS credentials:
   ```bash
   aws configure
   ```
2. Ensure you have the following permissions:
   - EC2, ECS, S3, IAM, Secrets Manager
   - CloudWatch, VPC, Application Load Balancer
   - ECR (Elastic Container Registry)

## Quick Start

### 1. Clone and Setup
```bash
git clone https://github.com/jplopezy/crypto-payroll-infrastructure.git
cd crypto-payroll-infrastructure
```

### 2. Configure Environment
```bash
# Copy environment template
cp env.example .env

# Edit configuration
nano .env
```

### 3. Deploy Infrastructure
```bash
# Make deployment script executable
chmod +x deploy.sh

# Deploy to development environment
./deploy.sh dev

# Deploy to production environment
./deploy.sh prod
```

## Manual Deployment Steps

### Step 1: Infrastructure Deployment
```bash
cd terraform

# Initialize Terraform
terraform init

# Create workspace
terraform workspace new dev

# Plan deployment
terraform plan -var="environment=dev"

# Apply infrastructure
terraform apply
```

### Step 2: Configure Secrets
```bash
# Set external API key
aws secretsmanager update-secret \
  --secret-id crypto-payroll/external-signing-api-key \
  --secret-string '{"api_key":"your-fireblocks-api-key","base_url":"https://api.fireblocks.io/v1"}'

# Set JWT signing key
aws secretsmanager update-secret \
  --secret-id crypto-payroll/jwt-signing-key \
  --secret-string '{"signing_key":"your-jwt-secret-key","algorithm":"HS256"}'
```

### Step 3: Build and Deploy Application
```bash
# Build Docker image
docker build -t crypto-payroll-api ./src

# Tag for ECR
docker tag crypto-payroll-api:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/crypto-payroll-api:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/crypto-payroll-api:latest

# Update ECS service
aws ecs update-service \
  --cluster crypto-payroll-dev-cluster \
  --service crypto-payroll-dev-service \
  --force-new-deployment
```

## Local Development

### Using Docker Compose
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f crypto-payroll-api

# Stop services
docker-compose down
```

### Manual Local Setup
```bash
cd src

# Install dependencies
npm install

# Start development server
npm run dev

# Run tests
npm test
```

## Testing the API

### Health Check
```bash
curl https://your-alb-dns-name/health
```

### Upload Payroll File
```bash
curl -X POST \
  -H "Content-Type: multipart/form-data" \
  -F "payrollFile=@sample-payroll.enc" \
  https://your-alb-dns-name/api/payroll/upload
```

### Wallet Authentication
```bash
# Get challenge
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"walletAddress":"0x1234567890123456789012345678901234567890"}' \
  https://your-alb-dns-name/api/auth/challenge

# Verify signature
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"walletAddress":"0x1234567890123456789012345678901234567890","signature":"0x...","challenge":"..."}' \
  https://your-alb-dns-name/api/auth/verify
```

## Monitoring and Maintenance

### View Logs
```bash
# ECS service logs
aws logs tail /aws/ecs/crypto-payroll-dev-cluster --follow

# Application logs
aws logs tail /aws/ecs/crypto-payroll-dev-cluster --filter-pattern "ERROR"
```

### Scale Service
```bash
# Scale to 3 instances
aws ecs update-service \
  --cluster crypto-payroll-dev-cluster \
  --service crypto-payroll-dev-service \
  --desired-count 3
```

### Update Application
```bash
# Build new image
docker build -t crypto-payroll-api:latest ./src

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/crypto-payroll-api:latest

# Force new deployment
aws ecs update-service \
  --cluster crypto-payroll-dev-cluster \
  --service crypto-payroll-dev-service \
  --force-new-deployment
```

## Security Considerations

### Secrets Management
- All secrets are stored in AWS Secrets Manager
- Secrets are encrypted at rest and in transit
- Regular rotation of API keys and signing keys

### Network Security
- VPC with private subnets for backend services
- Security groups with least-privilege access
- VPC endpoints for AWS services

### Application Security
- Rate limiting on all endpoints
- Input validation and sanitization
- Secure file upload handling
- JWT token authentication

## Troubleshooting

### Common Issues

1. **Terraform state locked**
   ```bash
   terraform force-unlock <lock-id>
   ```

2. **ECS service not starting**
   ```bash
   aws ecs describe-services --cluster <cluster-name> --services <service-name>
   ```

3. **Secrets not accessible**
   ```bash
   aws secretsmanager get-secret-value --secret-id <secret-name>
   ```

4. **S3 bucket access denied**
   ```bash
   aws s3 ls s3://<bucket-name>
   ```

### Support
For issues or questions, please:
1. Check the logs first
2. Review the troubleshooting section
3. Create an issue in the GitHub repository

## Cost Optimization

### Development Environment
- Use Fargate Spot instances
- Enable auto-scaling
- Set up cost alerts

### Production Environment
- Use Reserved Instances for predictable workloads
- Implement proper resource tagging
- Regular cost reviews and optimization
