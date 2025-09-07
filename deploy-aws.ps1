# Crypto Payroll API - AWS Deployment Script
# This script will deploy the entire infrastructure to AWS

Write-Host "🚀 Starting Crypto Payroll API Infrastructure Deployment" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# Set working directory
$terraformDir = "C:\EXAMEN BAX\crypto-payroll-infrastructure\terraform"
Set-Location $terraformDir

Write-Host "📁 Working directory: $terraformDir" -ForegroundColor Yellow

# Check if Terraform is installed
Write-Host "🔍 Checking Terraform installation..." -ForegroundColor Yellow
try {
    $terraformVersion = terraform --version
    Write-Host "✅ Terraform found: $terraformVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform not found. Please install Terraform first." -ForegroundColor Red
    exit 1
}

# Check AWS credentials
Write-Host "🔍 Checking AWS credentials..." -ForegroundColor Yellow
try {
    $awsIdentity = aws sts get-caller-identity
    Write-Host "✅ AWS credentials configured" -ForegroundColor Green
    Write-Host "Account: $($awsIdentity | ConvertFrom-Json | Select-Object -ExpandProperty Account)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ AWS credentials not configured. Please run 'aws configure' first." -ForegroundColor Red
    exit 1
}

# Initialize Terraform
Write-Host "🔧 Initializing Terraform..." -ForegroundColor Yellow
try {
    terraform init
    Write-Host "✅ Terraform initialized successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform initialization failed" -ForegroundColor Red
    exit 1
}

# Plan deployment
Write-Host "📋 Planning Terraform deployment..." -ForegroundColor Yellow
try {
    terraform plan -out=tfplan
    Write-Host "✅ Terraform plan created successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Terraform plan failed" -ForegroundColor Red
    exit 1
}

# Apply deployment
Write-Host "🚀 Deploying infrastructure to AWS..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Cyan
try {
    terraform apply tfplan
    Write-Host "✅ Infrastructure deployed successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Infrastructure deployment failed" -ForegroundColor Red
    exit 1
}

# Show outputs
Write-Host "📊 Deployment Summary:" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
try {
    terraform output
} catch {
    Write-Host "⚠️ Could not retrieve outputs" -ForegroundColor Yellow
}

# Configure secrets
Write-Host "🔐 Configuring secrets..." -ForegroundColor Yellow
try {
    $secretValue = @{
        api_key = "your-fireblocks-api-key-here"
        base_url = "https://api.fireblocks.io/v1"
        timeout = "30"
    } | ConvertTo-Json

    aws secretsmanager update-secret `
        --secret-id "crypto-payroll/external-signing-api-key" `
        --secret-string $secretValue
    
    Write-Host "✅ Secrets configured successfully" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not configure secrets automatically" -ForegroundColor Yellow
    Write-Host "Please configure secrets manually:" -ForegroundColor Cyan
    Write-Host "aws secretsmanager update-secret --secret-id crypto-payroll/external-signing-api-key --secret-string '{\"api_key\":\"your-key\"}'" -ForegroundColor White
}

# Show next steps
Write-Host "🎉 Deployment Complete!" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure your real API keys in AWS Secrets Manager" -ForegroundColor White
Write-Host "2. Build and push your Docker image to ECR" -ForegroundColor White
Write-Host "3. Update the ECS service with your application image" -ForegroundColor White
Write-Host "4. Test the API endpoints" -ForegroundColor White
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "• View ECS clusters: aws ecs list-clusters" -ForegroundColor White
Write-Host "• View S3 buckets: aws s3 ls" -ForegroundColor White
Write-Host "• View secrets: aws secretsmanager list-secrets" -ForegroundColor White
Write-Host "• View logs: aws logs describe-log-groups" -ForegroundColor White

Write-Host "🎯 Crypto Payroll API Infrastructure is now running in AWS!" -ForegroundColor Green
