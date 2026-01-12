terraform {
  required_providers {
    kafka = {
      source  = "Mongey/kafka"
      version = "~> 0.13.0"
    }
  }
}

provider "kafka" {
  bootstrap_servers = split(",", aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam)
  tls_enabled       = true
  sasl_mechanism    = "aws-iam"
  sasl_aws_region   = var.aws_region
}

# ACL to allow the Terraform runner identity to create and manage topics in the Kafka cluster.
resource "kafka_acl" "terraform_topic_creator_acl" {
  acl_principal       = "User:${data.aws_caller_identity.me.arn}"      
  acl_host            = "*"                                            
  acl_operation       = "Create"                                       
  acl_permission_type = "Allow"                                        
  resource_type       = "Topic"                                        
  resource_name       = "*"                                            
}

resource "kafka_topic" "produce_events" {
  name               = "ingestion.user.behavior.v1"
  partitions         = 3
  # Replication Factor (RF) should be >= 2 for high availability. 
  # Dev uses 2 for cost-saving; Production should use 3.
  replication_factor = 2

  config = {
    "cleanup.policy"      = "delete"
    "retention.ms"        = "86400000" # 1 day
    # min.insync.replicas should be (RF - 1) to ensure durability while allowing for single-node failure.
    "min.insync.replicas" = "1"        
  }

  lifecycle {
    prevent_destroy = true
  }
}

# --- Kafka Architecture Summary ---
# 1. Partitions & Brokers:
# Topics are divided into partitions for parallelism. Each partition has one 'Leader' broker 
# handling all read/write requests, and multiple 'Follower' brokers for data redundancy.

# 2. Replication Factor (RF):
# RF defines the total copies of each partition. RF=3 means 1 leader and 2 followers. 
# Replicas are distributed across different brokers to ensure fault tolerance.

# 3. High Availability (HA) & Fault Recovery:
# If a Leader broker fails, Kafka automatically elects a new Leader from the In-Sync Replicas (ISR).
# This leader/follower model ensures zero downtime and no data loss during infrastructure failures.

# 4. Partitioning Strategy:
# Increasing partition count improves consumer throughput by allowing more concurrent readers,
# but also increases metadata overhead.