# Queue that receives spot interruption notices
resource "aws_sqs_queue" "main" {
  name                      = "${var.project}-${var.environment}-karpenter-interruption"
  message_retention_seconds = 300

  tags = {
    Name = "${var.project}-${var.environment}-karpenter-interruption"
  }
}

# Allow EventBridge to write interruption events into the queue
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToQueue"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.main.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.spot_interruption.arn
          }
        }
      }
    ]
  })
}

# Catch EC2 spot interruption warnings and forward them to Karpenter
resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${var.project}-${var.environment}-spot-interruption"
  description = "Intercepts EC2 Spot Instance Interruption Warnings for Karpenter"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = {
    Name = "${var.project}-${var.environment}-spot-interruption"
  }
}

# Send matching interruption events to the SQS queue
resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "KarpenterSpotInterruptionQueueTarget"
  arn       = aws_sqs_queue.main.arn
}
