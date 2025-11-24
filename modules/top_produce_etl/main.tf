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
    Environment = var.environment
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

# ------------------------------------------------------------------------------
# AWS Glue Job
# This is the core resource of the ETL module. It defines the ETL job that
# will be executed by AWS Glue.
# ------------------------------------------------------------------------------

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
    script_location = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job.zip"
    python_version  = "3.9"
  }

  glue_version = var.glue_version

  # --- Execution and Resource Configuration ---
  worker_type         = var.worker_type
  number_of_workers   = var.number_of_workers
  timeout             = 60 # 超时时间 60 分钟
  max_retries         = 0    # No retries on failure by default

  # --- Default arguments passed to the script ---
  # 默认参数配置 (传递给 Spark 脚本的参数)
  default_arguments = {
    # --- 1. Glue 系统参数 (System Arguments) ---
    # 告诉 Glue 你的主脚本在 zip 包内的路径
    "--script"                           = "src/main/job_runner.py",
    
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
    
    # 引用额外的 Python 文件。
    # 你的 ETL 项目里有 src/utils/*.py，这些不是主脚本，而是依赖库。
    # 我们需要把它们打包成一个 zip 文件 (utils.zip)，上传到 S3。
    # Glue 启动时，会自动下载这个 zip 并解压到 PYTHONPATH 里，这样你的 job_runner.py 才能 `import utils.logger`。
    "--extra-py-files"                   = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/utils.zip"

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
    Project     = var.project_name
    Environment = var.environment
  }
}

# ------------------------------------------------------------------------------
# AWS Glue Trigger
# ------------------------------------------------------------------------------

# Defines a trigger to run the Glue job on a schedule.
resource "aws_glue_trigger" "etl_trigger" {
  # Only create this trigger if a schedule is provided.
  count = var.glue_trigger_schedule != null ? 1 : 0

  name          = "${var.project_name}-${var.environment}-etl-trigger"
  type          = "SCHEDULED"
  schedule      = var.glue_trigger_schedule
  enabled       = true

  actions {
    job_name = aws_glue_job.top_produce_etl_job.name
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-etl-trigger"
    Project     = var.project_name
    Environment = var.environment
  }
}

# 定义 Glue 数据库 (逻辑容器)
resource "aws_glue_catalog_database" "etl_database" {
  name = "${var.project_name}_${var.environment}_db" # e.g., data_platform_dev_db
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
  
  # 也可以给 Crawler 加个定时，比如 Job 跑完后 1 小时跑一次
  schedule = var.crawler_schedule

  tags = {
    Environment = var.environment
  }
}