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

# 授予当前 IAM 身份在 Kafka 集群中创建 Topic 的权限
resource "kafka_acl" "terraform_topic_creator_acl" {
  acl_principal       = "User:${data.aws_caller_identity.me.arn}"      # 这里的 User: 前缀是 Kafka ACL 的标准格式
  acl_host            = "*"                                            # 允许从任何主机访问
  acl_operation       = "Create"                                       # 允许执行创建操作
  acl_permission_type = "Allow"                                        # 允许
  resource_type       = "Topic"                                        # 针对 Topic 资源
  resource_name       = "*"                                            # 针对所有 Topic (允许创建任何 Topic)
}

resource "kafka_topic" "produce_events" {
  name               = "ingestion.user.behavior.v1"
  partitions         = 3
  replication_factor = 2

  # The replication_factor must be less than or equal to the number of your Brokers.
  # Your development environment has 3 Brokers, so 2 or 3 is acceptable.
  # It is recommended to set it to 2 or 3 to ensure high availability.

  # 6   # 副本因子(replication_factor)必须小于或等于您的 Broker 数量。
  # 7   # 您的开发环境中有 3 个 Broker，所以 2 或 3 都是可以的。
  # 8   # 建议设置为 2 或 3 以保证高可用。

  # You can also set other configurations for the Topic
  config = {
    "cleanup.policy" = "delete"
    "retention.ms"   = "86400000" # Retain for 1 day
  }

  lifecycle {
    prevent_destroy = true
  }
  
}

# resource "kafka_topic" "another_topic" {
#   name               = "another.topic.for.something.else"
#   partitions         = 6
#   replication_factor = 3
# }

# 1. 分区（Partition）与 Broker 的关系

# 首先，Kafka 主题会被分为多个 分区（partition）。分区是 Kafka 中用于存储消息的基本单位。每个分区是一个有序的消息队列。Kafka 将消息按顺序写入分区，并根据消费者的消费进度来读取消息。

# 每个分区只能由一个 leader broker 来处理读写操作，其他的 Kafka broker 被称为 follower broker，它们只是同步数据而不会处理实际的读写请求。

# Broker 的作用：

# Leader Broker：每个分区都有一个主分区，这个主分区由一个 leader broker 负责处理所有的消息写入和读取。

# Follower Brokers：其他的 follower broker 会作为备份存储分区的数据，实时同步 leader 的数据。

# 2. 副本因子（Replication Factor）与 Partition 的关系

# 副本因子（replication factor） 是指 Kafka 中每个分区的副本数。副本分布在不同的 Kafka broker 上，副本因子决定了每个分区的消息会有多少份副本被复制。副本的主要目的是为了保证 数据的高可用性和容错性。

# 如何影响 Partition：

# 副本：每个分区会有一个主副本（leader）和多个备份副本（followers）。副本因子指定了每个分区应该有几个副本。

# 副本因子 2：表示每个分区有 1 个 leader 和 1 个 follower 副本。

# 副本因子 3：表示每个分区有 1 个 leader 和 2 个 follower 副本。

# 这些副本被分布在不同的 broker 上。如果某个 broker 宕机，Kafka 会根据副本副本策略，将一个 follower 提升为 leader，以确保分区数据的可用性和完整性。

# 分区和副本的作用：

# 每个分区的 数据副本 存储在不同的 broker 上。这样，如果一个 broker 因为硬件故障或网络问题无法访问，其他 broker 上的副本仍然能够继续服务，保证数据的高可用性。

# 在正常情况下，消费者总是从 leader broker 获取数据，而 follower brokers 只是用来保持数据的一致性和备份。

# 当 leader broker 出现故障时，Kafka 会自动从 follower broker 中选择一个新的 leader 来接管，确保系统不宕机。

# 3. 如何通过 Partition 和 Replication 确保高可用性

# Kafka 的高可用性是通过 分区、副本 和 leader/follower 模型来实现的。让我们通过一个具体的例子来解释：

# 假设你有一个 Kafka 集群，包含 3 个 broker：

# Broker A

# Broker B

# Broker C

# 你有一个主题（topic），它的 partition 数量为 3，replication factor 为 3，这意味着：

# 每个分区会有 3 个副本，一个 leader 和两个 followers，并且这些副本会分布在不同的 broker 上。

# 例如，假设主题有 3 个分区，副本因子为 3，Kafka 可能会将这些分区和副本分配到 3 个 broker 上，分配如下：

# Partition 1：

# Leader: Broker A

# Follower 1: Broker B

# Follower 2: Broker C

# Partition 2：

# Leader: Broker B

# Follower 1: Broker C

# Follower 2: Broker A

# Partition 3：

# Leader: Broker C

# Follower 1: Broker A

# Follower 2: Broker B

# 这样做的好处是：

# 数据冗余：每个分区的数据会有多个副本，这些副本分布在不同的 broker 上。这意味着即使某个 broker 出现故障，其他 broker 上的副本仍然可以保证数据的可用性。

# 故障恢复：如果 Broker A 宕机，Kafka 会自动选举一个新的 leader：

# 对于 Partition 1，Broker A 原本是 leader，但现在它宕机，Kafka 会从 Partition 1 的 follower（比如 Broker B 或 C）中选择一个新的 leader。这个过程通常是自动完成的，Kafka 确保最少的中断时间。

# 负载均衡：通过将分区和副本分布在多个 broker 上，Kafka 可以平衡负载。如果某个 broker 被请求过多，系统可以将流量转移到其他 broker 上，提高整体的吞吐量和性能。

# 4. 副本因子的影响：

# 副本因子设置为 1：每个分区只有一个副本（即只有 leader），如果 leader 宕机，数据会丢失，Kafka 集群不可用。这种配置适用于对可用性要求不高的场景，但它没有容错性。

# 副本因子设置为 2 或 3：副本因子 2 或 3 提供了更强的容错性，即使一个 broker 宕机，数据仍然可以通过其他副本访问。副本因子为 3 时，可以容忍最多两个 broker 同时宕机。

# 总结：

# Partition：是数据的逻辑划分，每个分区存储一部分数据，Kafka 将数据分布在多个分区中，以便进行并行处理。

# Replication Factor：定义了每个分区的副本数，副本存储在不同的 broker 上。副本因子是确保数据高可用性和容错性的重要手段。

# 高可用性：通过副本分布在不同的 broker 上，Kafka 确保即使部分 broker 宕机，数据依然能够通过其他 broker 上的副本继续访问。

# Leader/Follower：每个分区都有一个 leader 和多个 follower，只有 leader 负责处理读写操作，而 follower 则同步数据并在 leader 宕机时接管其角色。

# 通过合理的分区数和副本因子配置，Kafka 可以提供高可用、容错且可扩展的消息流处理。