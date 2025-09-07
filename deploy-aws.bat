@echo off
echo 🚀 Starting Crypto Payroll API Infrastructure Deployment
echo =================================================

cd /d "C:\EXAMEN BAX\crypto-payroll-infrastructure\terraform"

echo 📁 Working directory: %CD%

echo 🔍 Checking Terraform installation...
terraform --version
if %errorlevel% neq 0 (
    echo ❌ Terraform not found. Please install Terraform first.
    pause
    exit /b 1
)
echo ✅ Terraform found

echo 🔍 Checking AWS credentials...
aws sts get-caller-identity
if %errorlevel% neq 0 (
    echo ❌ AWS credentials not configured. Please run 'aws configure' first.
    pause
    exit /b 1
)
echo ✅ AWS credentials configured

echo 🔧 Initializing Terraform...
terraform init
if %errorlevel% neq 0 (
    echo ❌ Terraform initialization failed
    pause
    exit /b 1
)
echo ✅ Terraform initialized successfully

echo 📋 Planning Terraform deployment...
terraform plan -out=tfplan
if %errorlevel% neq 0 (
    echo ❌ Terraform plan failed
    pause
    exit /b 1
)
echo ✅ Terraform plan created successfully

echo 🚀 Deploying infrastructure to AWS...
echo This may take several minutes...
terraform apply tfplan
if %errorlevel% neq 0 (
    echo ❌ Infrastructure deployment failed
    pause
    exit /b 1
)
echo ✅ Infrastructure deployed successfully!

echo 📊 Deployment Summary:
echo =====================
terraform output

echo 🔐 Configuring secrets...
aws secretsmanager update-secret --secret-id "crypto-payroll/external-signing-api-key" --secret-string "{\"api_key\":\"your-fireblocks-api-key-here\",\"base_url\":\"https://api.fireblocks.io/v1\",\"timeout\":\"30\"}"
if %errorlevel% neq 0 (
    echo ⚠️ Could not configure secrets automatically
    echo Please configure secrets manually:
    echo aws secretsmanager update-secret --secret-id crypto-payroll/external-signing-api-key --secret-string "{\"api_key\":\"your-key\"}"
) else (
    echo ✅ Secrets configured successfully
)

echo 🎉 Deployment Complete!
echo =====================
echo Next steps:
echo 1. Configure your real API keys in AWS Secrets Manager
echo 2. Build and push your Docker image to ECR
echo 3. Update the ECS service with your application image
echo 4. Test the API endpoints
echo.
echo Useful commands:
echo • View ECS clusters: aws ecs list-clusters
echo • View S3 buckets: aws s3 ls
echo • View secrets: aws secretsmanager list-secrets
echo • View logs: aws logs describe-log-groups

echo 🎯 Crypto Payroll API Infrastructure is now running in AWS!
pause
