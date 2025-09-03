# Data Platform Infrastructure

IaC for ingestion_kafka_flink and Top-produce-ETL.

## Project Structure

```
.
├── backend.tf          # Terraform backend configuration
├── main.tf             # Main Terraform configuration
├── outputs.tf          # Output definitions
├── providers.tf        # Provider configurations
├── variables.tf        # Variable definitions
├── terraform.tfvars    # Default variable values
├── modules/            # Reusable Terraform modules
│   ├── vpc/            # VPC module
│   ├── ecs/            # ECS module
│   ├── msk/            # MSK module
│   ├── s3/             # S3 module
│   ├── iam/            # IAM module
│   ├── glue/           # Glue module
│   ├── eventbridge/    # EventBridge module
│   ├── sns/            # SNS module
│   └── ec2/            # EC2 module
└── environments/       # Environment-specific configurations
    ├── dev/            # Development environment
    ├── staging/        # Staging environment
    └── prod/           # Production environment
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- AWS CLI configured with appropriate credentials

## Getting Started

1. Clone this repository
2. Install Terraform
3. Configure your AWS credentials:
   ```bash
   aws configure
   ```
4. Initialize Terraform:
   ```bash
   terraform init
   ```
5. Select your workspace (environment):
   ```bash
   terraform workspace select dev
   ```
6. Plan the infrastructure:
   ```bash
   terraform plan
   ```
7. Apply the infrastructure:
   ```bash
   terraform apply
   ```

## Environments

- **dev**: Development environment
- **staging**: Staging environment
- **prod**: Production environment

## Modules

This project uses the following modules:

- **VPC**: Creates VPC with public and private subnets
- **ECS**: Creates ECS cluster for containerized applications
- **MSK**: Creates Amazon MSK cluster for Kafka
- **S3**: Creates S3 buckets for data storage
- **IAM**: Creates IAM roles and policies
- **Glue**: Creates Glue resources for ETL jobs
- **EventBridge**: Creates EventBridge rules and targets
- **SNS**: Creates SNS topics and subscriptions
- **EC2**: Creates EC2 instances

## Variables

See `variables.tf` for a list of all variables and their descriptions.

## Outputs

See `outputs.tf` for a list of all outputs and their descriptions.

## Best Practices

1. Always use variables for configurable values
2. Use outputs to expose important resource attributes
3. Organize resources into modules for reusability
4. Use separate tfvars files for each environment
5. Use terraform fmt to format code consistently
6. Use terraform validate to check syntax
7. Use terraform plan before applying changes

## Contributing

1. Create a new branch for your changes
2. Make your changes
3. Run terraform fmt and terraform validate
4. Submit a pull request