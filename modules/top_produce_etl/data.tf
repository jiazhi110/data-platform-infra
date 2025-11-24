# 自带的，但是还是得声明。account_id   # 当前账户 ID，arn          # 当前调用者 ARN，user_id      # 当前调用者唯一 ID
data "aws_caller_identity" "me" {}
