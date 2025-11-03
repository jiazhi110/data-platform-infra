terraform {
  required_providers {
    # ... a pre-existing provider might be here ...
    kafka = {
      source  = "Mongey/kafka"
      version = "~> 0.11.0"
    }
  }
}

# Configure the Kafka Provider
provider "kafka" {
  # Since we are using IAM authentication, we need to reference the SASL/IAM bootstrap brokers provided by the MSK cluster.
  bootstrap_servers = aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam
  
  # Key: Configure IAM authentication
  sasl_iam {
    aws_region = var.aws_region
  }
}
