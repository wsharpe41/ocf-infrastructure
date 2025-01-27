# This is an temporary module.
# This will schedule the aws task to run on cron job.
# We want to move to Dagster but for the moment its useful to have this setup

resource "aws_cloudwatch_event_rule" "event_rule" {
  name                = "${var.consumer-name}-schedule-${var.environment}"
  schedule_expression = "cron(30 * * * ? *)"
  # runs every day on every 30 mins, will have to update this for production
}

resource "aws_cloudwatch_event_target" "ecs_scheduled_task" {

  rule      = aws_cloudwatch_event_rule.event_rule.name
  target_id = "${var.consumer-name}-schedule-${var.environment}"
  arn       = var.ecs-cluster.arn
  role_arn  = aws_iam_role.cloudwatch_role.arn

  ecs_target {

    launch_type         = "FARGATE"
    platform_version    = "1.4.0"
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.nwp-task-definition.arn
    network_configuration {

      subnets          = var.public_subnet_ids
      assign_public_ip = true

    }

  }

}
