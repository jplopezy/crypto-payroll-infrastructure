# Secrets Manager Configuration

# Secret for External Signing API Key
resource "aws_secretsmanager_secret" "external_api_key" {
  name                    = var.external_api_secret_name
  description             = "API key for external signing service (e.g., Fireblocks)"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-external-api-key"
  })
}

# Secret version with placeholder value
resource "aws_secretsmanager_secret_version" "external_api_key" {
  secret_id = aws_secretsmanager_secret.external_api_key.id
  secret_string = jsonencode({
    api_key = "your-external-api-key-here"
    base_url = "https://api.fireblocks.io/v1"
    timeout = "30"
  })
}

# Secret for Database credentials (if needed)
resource "aws_secretsmanager_secret" "database_credentials" {
  name                    = "${local.name_prefix}/database-credentials"
  description             = "Database credentials for crypto payroll service"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-database-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "database_credentials" {
  secret_id = aws_secretsmanager_secret.database_credentials.id
  secret_string = jsonencode({
    username = "crypto_payroll_user"
    password = "your-secure-password-here"
    host = "your-database-host"
    port = "5432"
    database = "crypto_payroll"
  })
}

# Secret for JWT signing key
resource "aws_secretsmanager_secret" "jwt_signing_key" {
  name                    = "${local.name_prefix}/jwt-signing-key"
  description             = "JWT signing key for authentication tokens"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-jwt-signing-key"
  })
}

resource "aws_secretsmanager_secret_version" "jwt_signing_key" {
  secret_id = aws_secretsmanager_secret.jwt_signing_key.id
  secret_string = jsonencode({
    signing_key = "your-jwt-signing-key-here"
    algorithm = "HS256"
    expiration_hours = "24"
  })
}

# Secret for encryption keys
resource "aws_secretsmanager_secret" "encryption_keys" {
  name                    = "${local.name_prefix}/encryption-keys"
  description             = "Encryption keys for sensitive data"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-encryption-keys"
  })
}

resource "aws_secretsmanager_secret_version" "encryption_keys" {
  secret_id = aws_secretsmanager_secret.encryption_keys.id
  secret_string = jsonencode({
    data_encryption_key = "your-data-encryption-key-here"
    file_encryption_key = "your-file-encryption-key-here"
    algorithm = "AES-256-GCM"
  })
}

# Secret for webhook signatures
resource "aws_secretsmanager_secret" "webhook_secrets" {
  name                    = "${local.name_prefix}/webhook-secrets"
  description             = "Webhook signature secrets for external integrations"
  recovery_window_in_days = 7

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-webhook-secrets"
  })
}

resource "aws_secretsmanager_secret_version" "webhook_secrets" {
  secret_id = aws_secretsmanager_secret.webhook_secrets.id
  secret_string = jsonencode({
    fireblocks_webhook_secret = "your-fireblocks-webhook-secret-here"
    slack_webhook_secret = "your-slack-webhook-secret-here"
  })
}

# KMS Key for Secrets Manager encryption
resource "aws_kms_key" "secrets_manager" {
  description             = "KMS key for Secrets Manager encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-secrets-manager-kms"
  })
}

resource "aws_kms_alias" "secrets_manager" {
  name          = "alias/${local.name_prefix}-secrets-manager"
  target_key_id = aws_kms_key.secrets_manager.key_id
}

# IAM Policy for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_access" {
  name        = "${local.name_prefix}-secrets-manager-access"
  description = "Policy for accessing Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.external_api_key.arn,
          aws_secretsmanager_secret.database_credentials.arn,
          aws_secretsmanager_secret.jwt_signing_key.arn,
          aws_secretsmanager_secret.encryption_keys.arn,
          aws_secretsmanager_secret.webhook_secrets.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.secrets_manager.arn
      }
    ]
  })

  tags = local.common_tags
}

# Attach secrets manager policy to ECS task role
resource "aws_iam_role_policy_attachment" "ecs_task_secrets_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.arn
}
