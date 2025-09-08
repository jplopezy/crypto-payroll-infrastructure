@echo off
echo 🐳 Building and Deploying Crypto Payroll API Application
echo =======================================================

cd /d "C:\EXAMEN BAX\crypto-payroll-infrastructure"

echo 📁 Working directory: %CD%

echo 🔍 Getting AWS account information...
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text') do set AWS_ACCOUNT_ID=%%i
echo AWS Account ID: %AWS_ACCOUNT_ID%

set AWS_REGION=us-east-1
set ECR_REGISTRY=%AWS_ACCOUNT_ID%.dkr.ecr.%AWS_REGION%.amazonaws.com
set IMAGE_TAG=%ECR_REGISTRY%/crypto-payroll-api:latest

echo 🐳 Building Docker image...
cd src
docker build -t crypto-payroll-api .
if %errorlevel% neq 0 (
    echo ❌ Docker build failed
    pause
    exit /b 1
)
echo ✅ Docker image built successfully

echo 🔐 Logging into ECR...
aws ecr get-login-password --region %AWS_REGION% | docker login --username AWS --password-stdin %ECR_REGISTRY%
if %errorlevel% neq 0 (
    echo ❌ ECR login failed
    pause
    exit /b 1
)
echo ✅ Logged into ECR successfully

echo 📦 Creating ECR repository...
aws ecr describe-repositories --repository-names crypto-payroll-api --region %AWS_REGION% >nul 2>&1
if %errorlevel% neq 0 (
    aws ecr create-repository --repository-name crypto-payroll-api --region %AWS_REGION%
    echo ✅ ECR repository created
) else (
    echo ✅ ECR repository already exists
)

echo 🏷️ Tagging Docker image...
docker tag crypto-payroll-api:latest %IMAGE_TAG%
if %errorlevel% neq 0 (
    echo ❌ Docker tag failed
    pause
    exit /b 1
)
echo ✅ Docker image tagged successfully

echo 📤 Pushing Docker image to ECR...
docker push %IMAGE_TAG%
if %errorlevel% neq 0 (
    echo ❌ Docker push failed
    pause
    exit /b 1
)
echo ✅ Docker image pushed successfully

echo 🔄 Updating ECS service...
aws ecs update-service --cluster crypto-payroll-cluster --service crypto-payroll-service --force-new-deployment
if %errorlevel% neq 0 (
    echo ❌ ECS service update failed
    pause
    exit /b 1
)
echo ✅ ECS service update initiated

echo ⏳ Waiting for deployment to complete...
aws ecs wait services-stable --cluster crypto-payroll-cluster --services crypto-payroll-service
if %errorlevel% neq 0 (
    echo ⚠️ Service deployment may still be in progress
) else (
    echo ✅ Service deployment completed successfully
)

echo 🎉 Application Deployment Complete!
echo =================================
echo Your Crypto Payroll API is now running in AWS ECS!
echo.
echo Image: %IMAGE_TAG%
echo Cluster: crypto-payroll-cluster
echo Service: crypto-payroll-service
echo.
echo Next steps:
echo 1. Get the service IP: aws ecs describe-services --cluster crypto-payroll-cluster --services crypto-payroll-service --query "services[0].deployments[0].status"
echo 2. Test the health endpoint: curl http://[SERVICE-IP]:3000/health
echo 3. Monitor logs: aws logs tail /aws/ecs/crypto-payroll --follow

pause
