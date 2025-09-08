package terraform

# Deny resources without required tags
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.tags
    msg := sprintf("S3 bucket %s must have tags", [resource.address])
}

deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ecs_cluster"
    not resource.change.after.tags
    msg := sprintf("ECS cluster %s must have tags", [resource.address])
}

# Require encryption for S3 buckets
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_s3_bucket"
    not resource.change.after.server_side_encryption_configuration
    msg := sprintf("S3 bucket %s must have encryption enabled", [resource.address])
}

# Require VPC for ECS services
deny[msg] {
    resource := input.resource_changes[_]
    resource.type == "aws_ecs_service"
    not resource.change.after.network_configuration
    msg := sprintf("ECS service %s must have network configuration", [resource.address])
}
