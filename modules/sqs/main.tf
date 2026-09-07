# Standard SQS queue carrying processor events from the Lambda to the
# backend's consumer (NOTIFY_MODE=sqs), plus the dead-letter queue the
# redrive policy points at.
#
#   uploads/ -> Lambda -> [this queue] -> backend SqsEventConsumerService
#
# The DLQ is created first and referenced by the main queue's redrive
# policy; nothing is ever a consumer *of* the DLQ — only the redrive writes
# to it, so it needs no extra policy statements.

locals {
  main_queue_name = "${var.name_prefix}-events"
  dlq_name        = "${var.name_prefix}-events-dlq"
}

resource "aws_sqs_queue" "dlq" {
  name = local.dlq_name

  # Messages landing here mean the consumer kept failing — keep them long
  # enough to debug, they are not automatically reprocessed.
  message_retention_seconds = var.dlq_retention_seconds

  tags = merge(var.tags, {
    Name = local.dlq_name
  })
}

resource "aws_sqs_queue" "events" {
  name = local.main_queue_name

  # At least 2x the worst-case Lambda processing time so a message isn't
  # re-delivered while its first consumer is still handling it.
  visibility_timeout_seconds = var.visibility_timeout_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = merge(var.tags, {
    Name = local.main_queue_name
  })
}

output "queue_url" {
  description = "Events queue URL (backend consumer + Lambda publisher env)."
  value       = aws_sqs_queue.events.url
}

output "queue_arn" {
  description = "Events queue ARN (Lambda send + backend receive policies)."
  value       = aws_sqs_queue.events.arn
}

output "dlq_url" {
  description = "Dead-letter queue URL (depth monitoring)."
  value       = aws_sqs_queue.dlq.url
}

output "dlq_arn" {
  description = "Dead-letter queue ARN."
  value       = aws_sqs_queue.dlq.arn
}