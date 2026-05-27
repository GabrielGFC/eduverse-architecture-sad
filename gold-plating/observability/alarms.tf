###############################################################################
# Alarms criticos EduVerse - Fase 3
# Cada alarm aponta para um item do runbook em ../docs-extra/runbook-oncall.md
###############################################################################

resource "aws_sns_topic" "oncall" {
  name = "eduverse-oncall-${var.environment}"
}

# ---- Circuit Breaker aberto sustentado > 5min --------------------------------
resource "aws_cloudwatch_metric_alarm" "breaker_open_sustained" {
  alarm_name          = "eduverse-breaker-open-sustained"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 5
  metric_name         = "CircuitBreakerState"
  namespace           = "EduVerse/Resilience"
  period              = 60
  statistic           = "Maximum"
  threshold           = 2  # 2 = open
  alarm_description   = "Circuit Breaker aberto ha mais de 5 minutos. Ver runbook secao 1."
  alarm_actions       = [aws_sns_topic.oncall.arn]
  treat_missing_data  = "notBreaching"
}

# ---- SQS mensagem mais antiga > 15min ----------------------------------------
resource "aws_cloudwatch_metric_alarm" "sqs_old_message" {
  for_each = toset([
    "eduverse-recommendation-jobs-${var.environment}",
    "eduverse-moodle-sync-${var.environment}"
  ])

  alarm_name          = "eduverse-sqs-old-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 900  # 15 min
  dimensions          = { QueueName = each.value }
  alarm_description   = "Fila ${each.value} com mensagem antiga > 15min. Ver runbook secao 2."
  alarm_actions       = [aws_sns_topic.oncall.arn]
}

# ---- DLQ recebendo mensagens -------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  for_each = toset([
    "eduverse-recommendation-dlq-${var.environment}",
    "eduverse-moodle-sync-dlq-${var.environment}"
  ])

  alarm_name          = "eduverse-dlq-${each.value}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  dimensions          = { QueueName = each.value }
  alarm_description   = "DLQ ${each.value} recebeu mensagem - falha persistente. Ver runbook secao 3."
  alarm_actions       = [aws_sns_topic.oncall.arn]
}

# ---- RDS storage critico < 20% -----------------------------------------------
resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "eduverse-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Minimum"
  threshold           = 10737418240  # 10 GB
  dimensions          = { DBInstanceIdentifier = "eduverse-${var.environment}" }
  alarm_description   = "RDS com menos de 10GB livre. Ver runbook secao 4."
  alarm_actions       = [aws_sns_topic.oncall.arn]
}

# ---- Lambda error rate > 5% em 10min -----------------------------------------
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name          = "eduverse-lambda-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  alarm_description   = "Lambda integrations com >5% de erro. Ver runbook secao 5."
  alarm_actions       = [aws_sns_topic.oncall.arn]

  metric_query {
    id          = "error_rate"
    expression  = "(errors / invocations) * 100"
    label       = "Error Rate (%)"
    return_data = true
  }
  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      dimensions  = { FunctionName = "eduverse-integrations-${var.environment}" }
      period      = 300
      stat        = "Sum"
    }
  }
  metric_query {
    id = "invocations"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Invocations"
      dimensions  = { FunctionName = "eduverse-integrations-${var.environment}" }
      period      = 300
      stat        = "Sum"
    }
  }
}

# ---- API Gateway 5xx > 1% ----------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "eduverse-apigw-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Average"
  threshold           = 0.01
  dimensions          = { ApiName = "eduverse-${var.environment}" }
  alarm_description   = "API Gateway com >1% de 5xx. Ver runbook secao 6."
  alarm_actions       = [aws_sns_topic.oncall.arn]
}
