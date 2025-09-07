#!/bin/bash

# Crypto Payroll API - Deployment Script
# This script automates the deployment process

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}
PROJECT_NAME="crypto-payroll"

echo -e "${GREEN}🚀 Starting deployment for environment: ${ENVIRONMENT}${NC}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_status "All prerequisites met!"
}

# Deploy infrastructure
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Initialize Terraform
    terraform init
    
    # Create workspace if it doesn't exist
    terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}
    
    # Plan deployment
    terraform plan -var="environment=${ENVIRONMENT}" -out=tfplan
    
    # Apply deployment
    terraform apply tfplan
    
    # Get outputs
    ECS_CLUSTER=$(terraform output -raw ecs_cluster_id)
    S3_BUCKET=$(terraform output -raw s3_bucket_name)
    ALB_DNS=$(terraform output -raw alb_dns_name)
    
    print_status "Infrastructure deployed successfully!"
    print_status "ECS Cluster: ${ECS_CLUSTER}"
    print_status "S3 Bucket: ${S3_BUCKET}"
    print_status "ALB DNS: ${ALB_DNS}"
    
    cd ..
}

# Build and push Docker image
build_and_push_image() {
    print_status "Building and pushing Docker image..."
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    IMAGE_TAG="${ECR_REGISTRY}/${PROJECT_NAME}-api:latest"
    
    # Login to ECR
    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
    
    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names ${PROJECT_NAME}-api --region ${AWS_REGION} || \
    aws ecr create-repository --repository-name ${PROJECT_NAME}-api --region ${AWS_REGION}
    
    # Build image
    docker build -t ${PROJECT_NAME}-api ./src
    
    # Tag image
    docker tag ${PROJECT_NAME}-api:latest ${IMAGE_TAG}
    
    # Push image
    docker push ${IMAGE_TAG}
    
    print_status "Docker image pushed successfully: ${IMAGE_TAG}"
}

# Deploy application
deploy_application() {
    print_status "Deploying application to ECS..."
    
    # Get ECS cluster name
    ECS_CLUSTER=$(cd terraform && terraform output -raw ecs_cluster_id)
    ECS_SERVICE="${PROJECT_NAME}-${ENVIRONMENT}-service"
    
    # Update ECS service
    aws ecs update-service \
        --cluster ${ECS_CLUSTER} \
        --service ${ECS_SERVICE} \
        --force-new-deployment
    
    # Wait for deployment to complete
    print_status "Waiting for deployment to complete..."
    aws ecs wait services-stable \
        --cluster ${ECS_CLUSTER} \
        --services ${ECS_SERVICE}
    
    print_status "Application deployed successfully!"
}

# Run security scans
run_security_scans() {
    print_status "Running security scans..."
    
    # Run tfsec
    if command -v tfsec &> /dev/null; then
        tfsec terraform/
    else
        print_warning "tfsec not installed, skipping Terraform security scan"
    fi
    
    # Run checkov
    if command -v checkov &> /dev/null; then
        checkov -d terraform/ --framework terraform
    else
        print_warning "checkov not installed, skipping infrastructure security scan"
    fi
    
    # Run npm audit
    if [ -f "src/package.json" ]; then
        cd src && npm audit --audit-level=high && cd ..
    fi
    
    print_status "Security scans completed!"
}

# Main deployment flow
main() {
    echo -e "${GREEN}🎯 Crypto Payroll API Deployment${NC}"
    echo -e "${GREEN}Environment: ${ENVIRONMENT}${NC}"
    echo -e "${GREEN}AWS Region: ${AWS_REGION}${NC}"
    echo ""
    
    check_prerequisites
    run_security_scans
    deploy_infrastructure
    build_and_push_image
    deploy_application
    
    echo ""
    print_status "🎉 Deployment completed successfully!"
    echo ""
    echo -e "${GREEN}📋 Next steps:${NC}"
    echo "1. Configure your secrets in AWS Secrets Manager"
    echo "2. Test the API endpoints"
    echo "3. Monitor the application logs"
    echo "4. Set up monitoring and alerting"
    echo ""
    echo -e "${GREEN}🔗 Useful commands:${NC}"
    echo "• View logs: aws logs tail /aws/ecs/${PROJECT_NAME}-${ENVIRONMENT}-cluster --follow"
    echo "• Check service status: aws ecs describe-services --cluster ${PROJECT_NAME}-${ENVIRONMENT}-cluster --services ${PROJECT_NAME}-${ENVIRONMENT}-service"
    echo "• Scale service: aws ecs update-service --cluster ${PROJECT_NAME}-${ENVIRONMENT}-cluster --service ${PROJECT_NAME}-${ENVIRONMENT}-service --desired-count 3"
}

# Run main function
main "$@"
