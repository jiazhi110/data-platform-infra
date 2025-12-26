# ------------------------------------------------------------------------------
# 1. ETL Assets Bucket
#    用于存放 ETL 脚本 (job_runner.py)、依赖包 (utils.zip) 和临时文件。
#    这实现了代码与数据的分离。
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "etl_assets" {
  bucket        = "${var.project_name}-${var.environment}-etl-assets-${var.aws_region}"
  force_destroy = true # 开发环境方便销毁，生产环境建议设为 false

  tags = {
    Name        = "${var.project_name}-etl-assets"
  }
}

# 安全最佳实践：阻止对 S3 的公网访问
resource "aws_s3_bucket_public_access_block" "etl_assets_block" {
  bucket = aws_s3_bucket.etl_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- ETL Assets 桶生命周期管理 ---
# 自动清理临时文件和日志，防止存储费用无限增长
resource "aws_s3_bucket_lifecycle_configuration" "etl_assets_lifecycle" {
  bucket = aws_s3_bucket.etl_assets.id

  # 规则 1: 清理 Glue 临时目录
  rule {
    id     = "expire-temporary-files"
    status = "Enabled"

    filter {
      prefix = "temporary/"
    }

    expiration {
      days = 7 # 临时文件只留 7 天
    }
  }

  # 规则 2: 清理 Spark UI 日志
  rule {
    id     = "expire-spark-logs"
    status = "Enabled"

    filter {
      prefix = "spark-logs/"
    }

    expiration {
      days = 30 # 日志留 30 天足够排查历史问题
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Glue Job

resource "aws_glue_job" "top_produce_etl_job" {
  name     = "${var.project_name}-${var.environment}-top-produce-etl"
  role_arn = aws_iam_role.glue_job_role.arn


  # command {
  #   script_location = var.glue_script_location
  #   python_version  = "3" # For Glue version 4.0, Python 3.10 is used.
  # }

  command {
    # 脚本位置：指向 S3 中的主程序文件
    # 注意：你需要配置 CI/CD 将代码上传到此路径
    # script_location = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/main/job_runner.py"
    # script_location = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job.zip"
    # 关键点：这里必须指向 .py 文件，而不是 .zip
    # 这样在 AWS Console 里就能看到正常的代码，而不是乱码
    script_location = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job_runner.py"
    python_version  = "3.9"
  }

  glue_version = var.glue_version

  # --- Execution and Resource Configuration ---
  worker_type         = var.worker_type
  number_of_workers   = var.number_of_workers
  timeout             = 60 # 超时时间 60 分钟
  max_retries         = 1    # 生产环境建议设为 1 或 3，Dev 环境可以设 1 容错

  # --- Default arguments passed to the script ---
  # 默认参数配置 (传递给 Spark 脚本的参数)
  default_arguments = {
    # --- 1. Glue 系统参数 (System Arguments) ---
    # 告诉 Glue 你的主脚本在 zip 包内的路径
    # 改了，用 script_location 了，不然在web console 中有乱码，garbled text
    # "--script"                           = "src/main/job_runner.py",

    # 关键点：这里指向 .zip 包 (包含 src 文件夹)
    "--extra-py-files" = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job.zip"
    
    # 配置文件路径 (注意：您的代码是用 boto3 读取这个文件的，所以它必须作为一个单独的文件存在于 S3，不能只在 zip 里)
    "--config_path"    = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/config/config_dev.yaml"
    
    # 指定作业语言类型，对于 Spark 任务通常是 "python" (PySpark) 或 "scala"
    "--job-language"                     = "python"
    
    # 开启连续日志。这意味着日志会实时推送到 CloudWatch，而不是等任务跑完才一次性上传。
    # 对 Debug 非常重要！如果不加这个，任务挂了你都看不到最后几行报错。
    "--enable-continuous-cloudwatch-log" = "true"
    
    # 开启 Spark UI。Glue 会生成 Spark 事件日志，让你能在 Spark History Server 里看到 DAG 图和任务详情。
    "--enable-spark-ui"                  = "true"
    
    # Spark UI 的日志存哪里？
    # 必须指定一个 S3 路径，Glue 会把运行时的 event logs 写到这儿。
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.etl_assets.bucket}/spark-logs/"
    
    # 临时目录。Glue 运行时需要暂存一些中间文件，最好显式指定，方便清理。
    "--TempDir"                          = "s3://${aws_s3_bucket.etl_assets.bucket}/temporary/"

    # --- 开启 Job Bookmarks (作业书签) ---
    # 核心功能：让 Glue 记录已处理的文件，下次运行时只处理增量数据。
    # 价值：避免全量扫描，大幅降低计算成本并处理迟到数据。
    "--job-bookmark-option"              = "job-bookmark-enable"

    # --- 2. 用户自定义参数 (User Arguments) ---
    # 这些参数会原封不动地传给你的 sys.argv，你的 Python 脚本需要解析它们。
    
    # 传入环境名称 (dev/prod)，你的代码可能需要据此读取不同的 config_dev.yaml
    "--ENV"                              = var.environment
    
    # 输入路径：告诉脚本去哪里读 Flink 产生的数据
    "--S3_SOURCE_PATH"                   = "s3://${var.source_s3_bucket_name}/user_action/"
    
    # 输出路径：告诉脚本处理完的数据存哪儿
    "--S3_OUTPUT_PATH"                   = "s3://${var.destination_s3_bucket_name}/batch_output/"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-top-produce-etl"
  }
}

# ------------------------------------------------------------------------------
# AWS Glue Trigger (已废弃 - 改用 Step Functions 编排)
# ------------------------------------------------------------------------------

# Defines a trigger to run the Glue job on a schedule.
# resource "aws_glue_trigger" "etl_trigger" {
#   # Only create this trigger if a schedule is provided.
#   count = var.glue_trigger_schedule != null ? 1 : 0
# 
#   name          = "${var.project_name}-${var.environment}-etl-trigger"
#   type          = "SCHEDULED"
#   schedule      = var.glue_trigger_schedule
#   enabled       = true
# 
#   actions {
#     job_name = aws_glue_job.top_produce_etl_job.name
#   }
# 
#   tags = {
#     Name        = "${var.project_name}-${var.environment}-etl-trigger"
#   }
# }

# 定义 Glue 数据库 (逻辑容器)
resource "aws_glue_catalog_database" "etl_database" {
  name = "${var.project_name}-${var.environment}-db" # e.g., data-platform-dev-db
}

# ------------------------------------------------------------------------------
# 5. AWS Glue Crawler (自动化元数据发现)
# 代替手动写 Table Schema。它扫描 ETL 输出路径，自动在 Catalog 里建表。
# ------------------------------------------------------------------------------
resource "aws_glue_crawler" "etl_crawler" {
  name          = "${var.project_name}-${var.environment}-crawler"
  database_name = aws_glue_catalog_database.etl_database.name
  role          = aws_iam_role.glue_job_role.arn # 复用 Role

  # 目标：扫描 ETL 任务输出的结果数据
  s3_target {
    path = "s3://${var.destination_s3_bucket_name}/batch_output/"
  }

  # 配置：检测到新列时更新表结构，检测到新分区时添加分区
  configuration = jsonencode({
    Version = 1.0 # 固定值，目前只有 1.0
    
    CrawlerOutput = {
      
      # --- 1. 分区 (Partitions) 的处理 ---
      # 这里的 AddOrUpdateBehavior = "InheritFromTable" 是什么意思？
      #
      # 场景：假设你的表已经建好了，现在 S3 里多了一个新文件夹 `dt=2023-11-22` (新分区)。
      # 默认行为：Crawler 会把这个新分区加进去，并且会尝试猜测这个新分区里的 Schema。
      #
      # "InheritFromTable" 的意思是：
      # "不管新分区里的文件长什么样，请直接沿用（继承）现在这张表已有的定义（SerDe, InputFormat 等）"。
      #
      # 为什么这很重要？
      # 这能防止因为某个分区里的坏数据或空文件，导致 Crawler 创建出一个格式错误的分区元数据。
      # 这对于生产环境非常重要，能保证表的稳定性。
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      
      # --- 2. 表结构 (Tables) 的处理 ---
      # 这里的 AddOrUpdateBehavior = "MergeNewColumns" 是什么意思？
      #
      # 场景：你的 Flink 代码改了，现在输出的数据里多了一个字段 `device_id`。
      #
      # "MergeNewColumns" 的意思是：
      # "如果你发现新数据里有新列，请把它加到现有的表定义里去，但不要删除旧列"。
      #
      # 这种模式叫 "Schema Evolution" (Schema 演进)。
      # 它允许你的业务逻辑灵活变更，而不需要每次改代码都去手动 `ALTER TABLE`。
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })
  
  # 已废弃 - 改由 Step Functions 触发
  # schedule = var.crawler_schedule
}

# ------------------------------------------------------------------------------
# 5.1 AWS Glue Catalog Table (Bootstrap Table)
# ------------------------------------------------------------------------------
# 预先定义表结构，解决 Data Quality Ruleset 的 "Entity Not Found" 依赖问题。
# 我们只定义核心字段，其余字段由 Crawler 在运行时自动发现和更新。
resource "aws_glue_catalog_table" "batch_output_table" {
  name          = "batch_output"
  database_name = aws_glue_catalog_database.etl_database.name
  table_type    = "EXTERNAL_TABLE" // 外部表：数据存储在外部（如 S3），删除表不影响数据。数据湖查询、Crawler 发现的表、ETL 输出。Glue 默认类型，最常用。

  storage_descriptor {
    location      = "s3://${var.destination_s3_bucket_name}/batch_output/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    // 提供序列化/反序列化（Serializer/Deserializer，简称SerDe）的信息。
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1" // 指定序列化格式的版本或行为，通常表示使用版本1的Hive序列化协议（对应于特定的行格式）。这确保兼容旧版Hive工具，避免类型转换问题。
      }
    }

    # 引导字段：只写一个，其余的交给 Crawler 自动合并
    columns {
      name    = "area_name"
      type    = "string"
      comment = "Bootstrap column - others discovered by crawler"
    }
  }

  parameters = {
    "classification" = "parquet"
  }
}

# ------------------------------------------------------------------------------
# 6. AWS Glue Data Quality (数据质量治理)
# ------------------------------------------------------------------------------
resource "aws_glue_data_quality_ruleset" "data_quality_check" {
  name        = "${var.project_name}-${var.environment}-dq-rules"
  description = "Validate data quality for the batch output table"

  # 绑定目标：指定之前创建的 Catalog 数据库和表
  target_table {
    database_name = aws_glue_catalog_database.etl_database.name
    table_name    = aws_glue_catalog_table.batch_output_table.name # 显式引用
  }

  # 规则集：使用 DQDL (Data Quality Definition Language) 语法定义
  # 基于 product_area_city_ratio_percent 的真实 Schema 进行校验
  ruleset = <<EOF
    Rules = [
        # 验证 1: 数据量检查 - 确保表里至少有一行数据，防止 ETL 逻辑异常导致产出空文件
        RowCount > 0,

        # 验证 2: 完整性检查 - 核心维度字段不能为空
        IsComplete "area_name",
        IsComplete "produce_name",

        # 验证 3: 业务逻辑检查 - 总点击数必须是正数
        ColumnValues "total_clicks" > 0
    ]
EOF

  tags = {
    Name = "${var.project_name}-dq-rules"
  }
}
