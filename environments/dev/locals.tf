locals {
  name_prefix = "${var.project_name}-${var.environment}"

  ecs_cluster_name  = "${local.name_prefix}-${var.ecs_cluster_name_suffix}"
  msk_cluster_name  = "${local.name_prefix}-${var.msk_cluster_name_suffix}"
  msk_sg_name       = "${local.name_prefix}-${var.msk_sg_name_suffix}"
  msk_scram_name    = "${var.msk_scram_name_prefix}_${local.name_prefix}_${var.msk_scram_name_suffix}"
  flink_task_family = "${local.name_prefix}-${var.flink_task_family_suffix}"

  glue_database_name = "${var.project_name}_${var.environment}_${var.glue_database_name_suffix}"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}