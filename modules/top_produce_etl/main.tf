# ------------------------------------------------------------------------------
# 1. ETL Assets Bucket
# ------------------------------------------------------------------------------
#    Bucket for storing ETL scripts (job_runner.py), dependencies (utils.zip), and temporary files.
#    This achieves the separation of code and data.
#    用于存放 ETL 脚本 (job_runner.py)、依赖包 (utils.zip) 和临时文件。
#    这实现了代码与数据的分离。
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "etl_assets" {
  bucket        = "${var.project_name}-${var.environment}-etl-assets-${var.aws_region}"
  # Convenient for destruction in dev environment; recommended to set to false in prod.
  force_destroy = true # 开发环境方便销毁，生产环境建议设为 false

  tags = {
    Name        = "${var.project_name}-etl-assets"
  }
}

# --- Enable Bucket Versioning ---
# Value: Version rollback capability for code and dependency packages.
# --- 启用桶版本控制 (Versioning) ---
# 价值：代码和依赖包的版本回滚能力
resource "aws_s3_bucket_versioning" "etl_assets_versioning" {
  bucket = aws_s3_bucket.etl_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Security best practice: Block public access to S3.
# 安全最佳实践：阻止对 S3 的公网访问
resource "aws_s3_bucket_public_access_block" "etl_assets_block" {
  bucket = aws_s3_bucket.etl_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- ETL Assets Bucket Lifecycle Management ---
# Automatically cleanup temporary files and logs to prevent infinite storage cost growth.
# --- ETL Assets 桶生命周期管理 ---
# 自动清理临时文件和日志，防止存储费用无限增长
resource "aws_s3_bucket_lifecycle_configuration" "etl_assets_lifecycle" {
  bucket = aws_s3_bucket.etl_assets.id

  # Rule 1: Cleanup old versions (Cost Optimization).
  # 规则 1: 清理旧版本 (Cost Optimization)
  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    # History versions will be completely cleared 30 days after the file is overwritten or deleted.
    # 如果文件被覆盖/删除，其历史版本保留 30 天后彻底清除
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Rule 2: Cleanup Glue temporary directory.
  # 规则 2: 清理 Glue 临时目录
  rule {
    id     = "expire-temporary-files"
    status = "Enabled"

    filter {
      prefix = "temporary/"
    }

    # Temporary files are retained for only 7 days.
    expiration {
      days = 7 # 临时文件只留 7 天
    }
  }

  # Rule 3: Cleanup Spark UI logs.
  # 规则 3: 清理 Spark UI 日志
  rule {
    id     = "expire-spark-logs"
    status = "Enabled"

    filter {
      prefix = "spark-logs/"
    }

    # Logs are retained for 30 days, which is enough for troubleshooting historical issues.
    expiration {
      days = 30 # 日志留 30 天足够排查历史问题
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Glue Job
# ------------------------------------------------------------------------------

resource "aws_glue_job" "top_produce_etl_job" {
  name     = "${var.project_name}-${var.environment}-top-produce-etl"
  role_arn = aws_iam_role.glue_job_role.arn


  # command {
  #   script_location = var.glue_script_location
  #   python_version  = "3" # For Glue version 4.0, Python 3.10 is used.
  # }

  command {
    # Script location: Pointing to the main program file in S3.
    # Note: You need to configure CI/CD to upload the code to this path.
    # 脚本位置：指向 S3 中的主程序文件
    # 注意：你需要配置 CI/CD 将代码上传到此路径
    # script_location = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/main/job_runner.py"
    # script_location = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job.zip"
    # Key point: This must point to the .py file, not the .zip.
    # This ensures normal code view in the AWS Console, instead of garbled text.
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
  # Production is recommended to be set to 1 or 3; Dev can be set to 1 for tolerance.
  max_retries         = 1    # 生产环境建议设为 1 或 3，Dev 环境可以设 1 容错

  # --- Default arguments passed to the script ---
  # Default parameter configuration (arguments passed to the Spark script).
  # 默认参数配置 (传递给 Spark 脚本的参数)
  default_arguments = {
    # --- 1. Glue System Arguments ---
    # --- 1. Glue 系统参数 (System Arguments) ---
    # Tell Glue the path of your main script inside the zip package.
    # Changed to use script_location to avoid garbled text in the web console.
    # 告诉 Glue 你的主脚本在 zip 包内的路径
    # 改了，用 script_location 了，不然在web console 中有乱码，garbled text
    # "--script"                           = "src/main/job_runner.py",

    # Key point: Point here to the .zip package (containing the src folder).
    # 关键点：这里指向 .zip 包 (包含 src 文件夹)
    "--extra-py-files" = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job.zip"
    
    # Configuration file path (Note: Your code reads this file using boto3, so it must exist as a separate file in S3, not just inside the zip).
    # 配置文件路径 (注意：您的代码是用 boto3 读取这个文件的，所以它必须作为一个单独的文件存在于 S3，不能只在 zip 里)
    "--config_path"    = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/config/config_dev.yaml"
    
    # Specify the job language type; typically "python" (PySpark) or "scala" for Spark tasks.
    # 指定作业语言类型，对于 Spark 任务通常是 "python" (PySpark) 或 "scala"
    "--job-language"                     = "python"
    
    # Enable continuous logging. This means logs are pushed to CloudWatch in real-time, rather than uploading all at once after the task finishes.
    # Very important for debugging! Without this, you cannot see the last few lines of error reports if the task crashes.
    # 开启连续日志。这意味着日志会实时推送到 CloudWatch，而不是等任务跑完才一次性上传。
    # 对 Debug 非常重要！如果不加这个，任务挂了你都看不到最后几行报错。
    "--enable-continuous-cloudwatch-log" = "true"
    
    # Enable Spark UI. Glue will generate Spark event logs, allowing you to see the DAG and task details in the Spark History Server.
    # 开启 Spark UI。Glue 会生成 Spark 事件日志，让你能在 Spark History Server 里看到 DAG 图和任务详情。
    "--enable-spark-ui"                  = "true"
    
    # Where to store Spark UI logs?
    # An S3 path must be specified; Glue will write runtime event logs here.
    # Spark UI 的日志存哪里？
    # 必须指定一个 S3 路径，Glue 会把运行时的 event logs 写到这儿。
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.etl_assets.bucket}/spark-logs/"
    
    # Temporary directory. Glue needs to stage some intermediate files during runtime; it's best to specify this explicitly for easier cleanup.
    # 临时目录。Glue 运行时需要暂存一些中间文件，最好显式指定，方便清理。
    "--TempDir"                          = "s3://${aws_s3_bucket.etl_assets.bucket}/temporary/"

    # --- Enable Job Bookmarks ---
    # Core function: Let Glue record processed files and only process incremental data next time.
    # Value: Avoid full scans, significantly reducing computation costs and handling late-arriving data.
    # --- 开启 Job Bookmarks (作业书签) ---
    # 核心功能：让 Glue 记录已处理的文件，下次运行时只处理增量数据。
    # 价值：避免全量扫描，大幅降低计算成本并处理迟到数据。
    "--job-bookmark-option"              = "job-bookmark-enable"

    # --- Enable Auto Scaling ---
    # Core function: AWS automatically adjusts the number of workers dynamically based on the task load.
    # Value: Reduce worker usage at the start of the task and automatically scale up during computation-intensive phases, significantly lowering costs and improving efficiency.
    # --- 开启 Auto Scaling (自动扩容) ---
    # 核心功能：AWS 自动根据任务负载动态调整 Worker 数量。
    # 价值：在任务开始阶段减少 Worker 使用，在计算密集阶段自动扩容，显著降低费用并提高效率。
    "--enable-auto-scaling"              = "true"

    # --- 2. User Arguments ---
    # These parameters will be passed directly to your sys.argv; your Python script needs to parse them.
    # --- 2. 用户自定义参数 (User Arguments) ---
    # 这些参数会原封不动地传给你的 sys.argv，你的 Python 脚本需要解析它们。
    
    # Pass environment name (dev/prod); your code might need to read different config_dev.yaml based on this.
    # 传入环境名称 (dev/prod)，你的代码可能需要据此读取不同的 config_dev.yaml
    "--ENV"                              = var.environment
    
    # Input path: Tell the script where to read data produced by Flink.
    # 输入路径：告诉脚本去哪里读 Flink 产生的数据
    "--S3_SOURCE_PATH"                   = "s3://${var.source_s3_bucket_name}/user_action/"
    
    # Output path: Tell the script where to store processed data.
    # 输出路径：告诉脚本处理完的数据存哪儿
    "--S3_OUTPUT_PATH"                   = "s3://${var.destination_s3_bucket_name}/batch_output/"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-top-produce-etl"
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group (Glue)
# ------------------------------------------------------------------------------
# Manually create a log group to manage the log retention policy, preventing logs from being retained permanently and incurring unnecessary costs.
# Note: The log group name must match the Glue task name for Glue to write automatically.
# 手动创建日志组以管理日志的保留策略，防止日志永久留存产生不必要的费用。
# 注意：日志组名称必须与 Glue 任务名称匹配，Glue 才能自动写入。
resource "aws_cloudwatch_log_group" "glue_logs" {
  # This is hardcoded as required by the convention.
  name              = "/aws-glue/jobs/${aws_glue_job.top_produce_etl_job.name}" // 这个是硬编码，就是这么写的，注意
  retention_in_days = 14 # 保留 14 天
}

# ------------------------------------------------------------------------------
# AWS Glue Trigger (Deprecated - Replaced by Step Functions orchestration)
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

# Define Glue Database (Logical container).
# 定义 Glue 数据库 (逻辑容器)
resource "aws_glue_catalog_database" "etl_database" {
  name = "${var.project_name}-${var.environment}-db" # e.g., data-platform-dev-db
}

# ------------------------------------------------------------------------------
# 5. AWS Glue Crawler (Automated Metadata Discovery)
# Replace manual Table Schema writing. It scans ETL output paths and automatically creates tables in the Catalog.
# 代替手动写 Table Schema。它扫描 ETL 输出路径，自动在 Catalog 里建表。
# ------------------------------------------------------------------------------
resource "aws_glue_crawler" "etl_crawler" {
  name          = "${var.project_name}-${var.environment}-crawler"
  database_name = aws_glue_catalog_database.etl_database.name
  # Reuse Role
  role          = aws_iam_role.glue_job_role.arn # 复用 Role

  # Target: Scan the output results data of the ETL task.
  # 目标：扫描 ETL 任务输出的结果数据
  s3_target {
    path = "s3://${var.destination_s3_bucket_name}/batch_output/"
  }

  # Configuration: Update table structure when new columns are detected, and add partitions when new partitions are detected.
  # 配置：检测到新列时更新表结构，检测到新分区时添加分区
  configuration = jsonencode({
    Version = 1.0 # 固定值，目前只有 1.0
    
    CrawlerOutput = {
      
      # --- 1. Handling Partitions ---
      # What does AddOrUpdateBehavior = "InheritFromTable" mean here?
      #
      # Scenario: Suppose your table is already built, and now there is a new folder `dt=2023-11-22` (new partition) in S3.
      # Default behavior: Crawler will add this new partition and try to guess the Schema inside it.
      #
      # "InheritFromTable" means:
      # "Regardless of what the files in the new partition look like, please directly use (inherit) the existing definitions of this table (SerDe, InputFormat, etc.)."
      #
      # Why is this important?
      # This prevents the Crawler from creating incorrect partition metadata due to bad data or empty files in a partition.
      # This is crucial for production environments to ensure table stability.
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
      
      # --- 2. Handling Table Structures ---
      # What does AddOrUpdateBehavior = "MergeNewColumns" mean here?
      #
      # Scenario: Your Flink code has changed, and now the output data includes a new field `device_id`.
      #
      # "MergeNewColumns" means:
      # "If you discover new columns in the new data, please add them to the existing table definition, but do not delete old columns."
      #
      # This pattern is called "Schema Evolution".
      # It allows your business logic to change flexibly without needing to manually `ALTER TABLE` every time code is changed.
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
  
  # Deprecated - Triggered by Step Functions.
  # 已废弃 - 改由 Step Functions 触发
  # schedule = var.crawler_schedule
}

# ------------------------------------------------------------------------------
# 5.1 AWS Glue Catalog Table (Bootstrap Table)
# ------------------------------------------------------------------------------
# Pre-define table structure to resolve the "Entity Not Found" dependency issue of the Data Quality Ruleset.
# We only define core fields; remaining fields will be automatically discovered and updated by the Crawler at runtime.
# 预先定义表结构，解决 Data Quality Ruleset 的 "Entity Not Found" 依赖问题。
# 我们只定义核心字段，其余字段由 Crawler 在运行时自动发现和更新。
# ------------------------------------------------------------------------------
resource "aws_glue_catalog_table" "batch_output_table" {
  name          = "batch_output"
  database_name = aws_glue_catalog_database.etl_database.name
  # EXTERNAL_TABLE: Data is stored externally (e.g., S3); deleting the table does not affect the data. Commonly used for data lake queries and ETL output.
  table_type    = "EXTERNAL_TABLE" // 外部表：数据存储在外部（如 S3），删除表不影响数据。数据湖查询、Crawler 发现的表、ETL 输出。Glue 默认类型，最常用。

  storage_descriptor {
    location      = "s3://${var.destination_s3_bucket_name}/batch_output/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    # Provide SerDe (Serializer/Deserializer) information.
    // 提供序列化/反序列化（Serializer/Deserializer，简称SerDe）的信息。
    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        # Specify serialization format behavior, typically Hive version 1 protocol.
        "serialization.format" = "1" // 指定序列化格式的版本或行为，通常表示使用版本1的Hive序列化协议（对应于特定的行格式）。这确保兼容旧版Hive工具，避免类型转换问题。
      }
    }

    # Bootstrap column: Only write one; others will be automatically merged by the Crawler.
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
# 6. AWS Glue Data Quality (Data Governance)
# 6. AWS Glue Data Quality (数据质量治理)
# ------------------------------------------------------------------------------
resource "aws_glue_data_quality_ruleset" "data_quality_check" {
  name        = "${var.project_name}-${var.environment}-dq-rules"
  description = "Validate data quality for the batch output table"

  # Binding target: Specify the previously created Catalog database and table.
  # 绑定目标：指定之前创建的 Catalog 数据库和表
  target_table {
    database_name = aws_glue_catalog_database.etl_database.name
    # Explicit reference
    table_name    = aws_glue_catalog_table.batch_output_table.name # 显式引用
  }

  # Ruleset: Defined using DQDL (Data Quality Definition Language) syntax.
  # Validating based on the real Schema of product_area_city_ratio_percent.
  # 规则集：使用 DQDL (Data Quality Definition Language) 语法定义
  # 基于 product_area_city_ratio_percent 的真实 Schema 进行校验
  ruleset = <<EOF
    Rules = [
        # Validation 1: Row count check - Ensure at least one row of data exists to prevent empty files from ETL logic issues.
        # 验证 1: 数据量检查 - 确保表里至少有一行数据，防止 ETL 逻辑异常导致产出空文件
        RowCount > 0,

        # Validation 2: Completeness check - Ensure core dimension fields are not empty.
        # 验证 2: 完整性检查 - 核心维度字段不能为空
        IsComplete "area_name",
        IsComplete "produce_name",

        # Validation 3: Business logic check - Total clicks must be positive.
        # 验证 3: 业务逻辑检查 - 总点击数必须是正数
        ColumnValues "total_clicks" > 0
    ]
EOF

  tags = {
    Name = "${var.project_name}-dq-rules"
  }
}