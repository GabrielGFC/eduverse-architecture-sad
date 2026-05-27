###############################################################################
# Module: fargate-service
# Provisiona um servico ECS Fargate com ALB target group, log group,
# autoscaling horizontal por CPU e role minima.
###############################################################################

variable "name"           { type = string }
variable "cluster_id"     { type = string }
variable "vpc_id"         { type = string }
variable "subnets"        { type = list(string) }
variable "image"          { type = string }
variable "container_port" { type = number }
variable "cpu"            { type = number }
variable "memory"         { type = number }
variable "desired_count"  { type = number }
variable "min_capacity"   { type = number }
variable "max_capacity"   { type = number }
variable "target_cpu"     { type = number, default = 60 }

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = 30
}

resource "aws_iam_role" "task_exec" {
  name = "${var.name}-task-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_exec_managed" {
  role       = aws_iam_role.task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_exec.arn

  container_definitions = jsonencode([{
    name      = var.name
    image     = var.image
    essential = true
    portMappings = [{ containerPort = var.container_port, protocol = "tcp" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.name
        awslogs-stream-prefix = "ecs"
      }
    }
    environment = [
      { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://localhost:4317" },
      { name = "AWS_XRAY_TRACING_NAME",       value = var.name }
    ]
  }])
}

data "aws_region" "current" {}

resource "aws_security_group" "svc" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id
  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["10.20.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnets
    security_groups = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  deployment_controller { type = "ECS" }

  lifecycle { ignore_changes = [desired_count] }  # gerenciado pelo autoscaling
}

# ---- Autoscaling horizontal (ADR-0001) --------------------------------------
resource "aws_appautoscaling_target" "this" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${split("/", var.cluster_id)[1]}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name}-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.target_cpu
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}

output "service_name" { value = aws_ecs_service.this.name }
output "log_group"    { value = aws_cloudwatch_log_group.this.name }
