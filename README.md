# Data Platform Infrastructure on AWS

A production-grade, end-to-end data platform implementing **Lambda Architecture** concepts using **Terraform (IaC)**. This platform handles real-time ingestion via Kafka/Flink and batch processing via AWS Glue, delivering insights through Athena and QuickSight.

![Architecture Diagram](https://via.placeholder.com/800x400.png?text=Architecture+Diagram:+Mock+->+MSK+->+Flink+->+S3+->+Glue+->+Athena)
*(Note: Use draw.io to generate and commit the actual architecture diagram)*

## 🚀 Key Features & Highlights

### 1. Real-Time Ingestion Layer
*   **AWS MSK (Managed Kafka)**: Serves as the streaming backbone. Configured with **IAM Authentication** for zero-secret management and **MinISR=1** for high availability during maintenance.
*   **Apache Flink on ECS Fargate**: Deployed in **Application Mode**. Handles real-time processing with **RocksDB State Backend** and **S3 Checkpointing** for exactly-once semantics.

### 2. Batch Processing & Data Governance
*   **AWS Glue**: Serverless Spark jobs for complex ETL (e.g., Area-based Top 3 Product Ranking).
*   **Data Quality (DQDL)**: Integrated **AWS Glue Data Quality** to validate business logic (e.g., `total_clicks > 0`) before data consumption.
*   **Catalog Sync**: Automatic schema discovery via Glue Crawlers, enabling metadata-driven analysis in Athena.

### 3. Security & Zero-Trust Access
*   **Isolated Infrastructure**: All compute resources (MSK, Flink, Glue) reside in VPC **Private Subnets**.
*   **Secured Management**: Flink UI is shielded from the public internet. Access is restricted ONLY to the **GitHub Self-hosted Runner** (Security Group Level), enabling secure debugging via SSH/SSM tunneling.
*   **Hardened Storage**: Every S3 bucket enforces **AES-256 Encryption** and **Public Access Block**.

### 4. Operational Excellence (FinOps & DevOps)
*   **Cost Optimized**: Single NAT Gateway for Dev environments; **S3 Lifecycle Rules** to auto-expire Flink Checkpoints (3d) and Savepoints (7d).
*   **Observability**: Real-time alerting via **SNS + CloudWatch** for ETL failures and Task interruptions. Centralized logging in **CloudWatch Logs**.

## 🛠️ Prerequisites & Getting Started

### Prerequisites
*   **Terraform** ~> 1.5
*   **AWS CLI** configured with appropriate credentials
*   **Docker** for building Flink/Producer images

### Deployment Steps
1.  **Network Layer**: Establish the VPC foundation.
    ```bash
    cd environments/network
    terraform init && terraform apply
    ```
2.  **Application Layer**: Deploy Kafka, Flink, and Glue.
    ```bash
    cd ../dev
    terraform init && terraform apply
    ```

## 🤖 CI/CD & Automation
This project leverages **GitHub Actions** for automated infrastructure management:
*   **Validation**: Automated `terraform validate` and `terraform fmt` checks.
*   **GitOps Deployment**: Changes are applied via a **Self-hosted Runner** within the VPC, ensuring secure deployment and credential isolation.

## 🛠️ Post-Deployment Operations
*   **Platform Dashboard**: Run `terraform output` to retrieve **MSK Bootstrap brokers**, S3 bucket names, and Glue job identifiers.
*   **Access UI**: Use SSH Tunneling via the Runner EC2 to access Flink UI on `localhost:8081`.
*   **Log Exploration**: Use **CloudWatch Logs Insights** to debug Flink tasks and Glue Spark jobs.

## 📂 Repository Structure

```
.
├── environments/
│   ├── dev/                 # Entry point: Minimalist config, core business params only
│   └── network/             # Core Network Layer (Independent State)
└── modules/
    ├── ingestion_kafka_flink/ # Streaming Layer (MSK, Flink, IAM, S3)
    ├── top_produce_etl/       # Batch Layer (Glue, Catalog, Athena, Data Quality)
    └── monitoring/            # Observability Layer (Shared SNS Alerts)
```

## 📈 Future Roadmap
*   **Real-time Serving**: Implement **Amazon ElastiCache (Redis)** for sub-second latency on dashboard metrics.
*   **Schema Evolution**: Integrate **Glue Schema Registry** for strict Avro/Protobuf validation.
*   **Enhanced Testing**: Integrate **Terratest** and native **Terraform Test** framework for module validation.
