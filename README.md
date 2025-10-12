# Data Platform Infrastructure

IaC for ingestion_kafka_flink and Top-produce-ETL.

## Project Structure

```
├── README.md
├── providers.tf
│
├── environments/
│   ├── dev/
│   │   ├── backend.tf           # dev 环境的 state 文件配置
│   │   ├── locals.tf            # dev 环境的本地变量
│   │   ├── main.tf              # 编排 dev 环境所有模块
│   │   ├── outputs.tf           # 输出 dev 环境的重要信息
│   │   └── terraform.tfvars     # dev 环境的专属配置
│   │
│   └── prod/
│       ├── backend.tf           # prod 环境的 state 文件配置
│       ├── main.tf              # 编排 prod 环境所有模块
│       ├── outputs.tf
│       └── terraform.tfvars     # prod 环境的专属配置
│
└── modules/
    ├── networking/              # 模块1: 共享网络
    │   ├── data.tf
    │   ├── locals.tf
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    │
    ├── ingestion_kafka_flink/   # 模块2: 实时摄取应用
    │   ├── main.tf              # 定义 MSK, Flink App, S3, IAM 等资源
    │   ├── variables.tf
    │   └── outputs.tf
    │
    └── top_produce_etl/         # 模块3: 批量ETL应用
        ├── main.tf              # 定义 Glue Job, Step Function, S3, IAM 等资源
        ├── variables.tf
        └── outputs.tf
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
- **prod**: Production environment

Note: The staging environment has been removed from the current implementation.

## Modules

This project uses the following modules:

- **networking**: Creates VPC with public and private subnets, Internet Gateway, and Route Tables
- **ingestion_kafka_flink**: Creates resources for real-time data ingestion including MSK, Flink applications, S3 buckets, and IAM roles
- **top_produce_etl**: Creates resources for batch ETL processing including Glue Jobs, Step Functions, S3 buckets, and IAM roles

## Variables

Each environment has its own `terraform.tfvars` file with environment-specific configurations.

## Outputs

Each module has its own `outputs.tf` file that exposes important resource attributes.

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