# Terraform Backend Configuration
# This file should be customized for your environment

terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "crypto-payroll/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
