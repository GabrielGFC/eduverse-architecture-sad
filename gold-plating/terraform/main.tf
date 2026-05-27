###############################################################################
# EduVerse - Fase 3 - Infrastructure as Code
#
# Provisiona a topologia descrita no ADR-0001 (AWS PaaS + Serverless).
# Este arquivo e um esqueleto declarativo: foca em estrutura, naming e
# dependencias entre recursos. Variaveis sensiveis ficam em dev.tfvars.
###############################################################################

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "eduverse-tfstate"
    key            = "fase3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "eduverse-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "EduVerse"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "gabriel.carvalho"
      CostCenter  = "academic"
    }
  }
}

###############################################################################
# Rede - VPC Multi-AZ (3 AZ) com subnets publicas e privadas
###############################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "eduverse-${var.environment}"
  cidr = "10.20.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  public_subnets  = ["10.20.0.0/24", "10.20.1.0/24", "10.20.2.0/24"]
  private_subnets = ["10.20.10.0/24", "10.20.11.0/24", "10.20.12.0/24"]
  database_subnets = ["10.20.20.0/24", "10.20.21.0/24", "10.20.22.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = var.environment == "dev"
  enable_dns_hostnames   = true
  enable_flow_log        = true
  flow_log_destination_type = "cloud-watch-logs"
}

###############################################################################
# RDS PostgreSQL Multi-AZ - schema-per-service
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "eduverse-${var.environment}"
  subnet_ids = module.vpc.database_subnets
}

resource "aws_security_group" "rds" {
  name        = "eduverse-rds-${var.environment}"
  vpc_id      = module.vpc.vpc_id
  description = "Acesso ao Postgres restrito as subnets privadas"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks     = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "main" {
  identifier              = "eduverse-${var.environment}"
  engine                  = "postgres"
  engine_version          = "16.3"
  instance_class          = var.db_instance_class
  allocated_storage       = 50
  max_allocated_storage   = 200
  storage_type            = "gp3"
  storage_encrypted       = true

  db_name                 = "eduverse"
  username                = var.db_username
  password                = var.db_password  # rotacionar via Secrets Manager em prod

  multi_az                = true
  publicly_accessible     = false
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.main.name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  deletion_protection     = var.environment == "prod"
  skip_final_snapshot     = var.environment != "prod"

  performance_insights_enabled = true
  monitoring_interval          = 60
}

###############################################################################
# ElastiCache Redis (cache de recomendacoes)
###############################################################################

resource "aws_elasticache_subnet_group" "main" {
  name       = "eduverse-${var.environment}"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "eduverse-${var.environment}"
  description                = "Cache de recomendacoes e sessoes"
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.t4g.small"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
}

###############################################################################
# ECS Fargate Cluster - hospeda 3 servicos sincronos
###############################################################################

resource "aws_ecs_cluster" "main" {
  name = "eduverse-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Cada servico (identity, adaptive-learning, assessment) e um modulo separado
# que recebe imagem, porta, env vars e politicas de autoscaling.
# Ver: modules/fargate-service/

module "identity_service" {
  source = "./modules/fargate-service"

  name          = "identity-service"
  cluster_id    = aws_ecs_cluster.main.id
  vpc_id        = module.vpc.vpc_id
  subnets       = module.vpc.private_subnets
  image         = "${var.ecr_registry}/identity-service:${var.image_tag}"
  container_port = 8080
  cpu           = 512
  memory        = 1024
  desired_count = 2
  min_capacity  = 2
  max_capacity  = 10
  target_cpu    = 60
}

module "adaptive_learning_service" {
  source = "./modules/fargate-service"

  name          = "adaptive-learning-service"
  cluster_id    = aws_ecs_cluster.main.id
  vpc_id        = module.vpc.vpc_id
  subnets       = module.vpc.private_subnets
  image         = "${var.ecr_registry}/adaptive-learning-service:${var.image_tag}"
  container_port = 8080
  cpu           = 1024
  memory        = 2048
  desired_count = 2
  min_capacity  = 2
  max_capacity  = 20
  target_cpu    = 60
}

module "assessment_service" {
  source = "./modules/fargate-service"

  name          = "assessment-service"
  cluster_id    = aws_ecs_cluster.main.id
  vpc_id        = module.vpc.vpc_id
  subnets       = module.vpc.private_subnets
  image         = "${var.ecr_registry}/assessment-service:${var.image_tag}"
  container_port = 8080
  cpu           = 512
  memory        = 1024
  desired_count = 2
  min_capacity  = 2
  max_capacity  = 30  # pico em janela de avaliacoes
  target_cpu    = 60
}

###############################################################################
# Bus de eventos + filas (ADR-0003)
###############################################################################

resource "aws_cloudwatch_event_bus" "eduverse" {
  name = "eduverse-${var.environment}"
}

resource "aws_sqs_queue" "recommendation_dlq" {
  name                       = "eduverse-recommendation-dlq-${var.environment}"
  message_retention_seconds  = 1209600  # 14 dias
}

resource "aws_sqs_queue" "recommendation_jobs" {
  name                       = "eduverse-recommendation-jobs-${var.environment}"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.recommendation_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_sqs_queue" "moodle_sync_dlq" {
  name = "eduverse-moodle-sync-dlq-${var.environment}"
}

resource "aws_sqs_queue" "moodle_sync" {
  name                       = "eduverse-moodle-sync-${var.environment}"
  visibility_timeout_seconds = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.moodle_sync_dlq.arn
    maxReceiveCount     = 5
  })
}

###############################################################################
# Lambda - integrations-service
###############################################################################

resource "aws_lambda_function" "integrations" {
  function_name = "eduverse-integrations-${var.environment}"
  runtime       = "nodejs20.x"
  handler       = "dist/handler.main"
  role          = aws_iam_role.lambda_integrations.arn
  filename      = var.lambda_zip
  source_code_hash = filebase64sha256(var.lambda_zip)
  memory_size   = 512
  timeout       = 30
  reserved_concurrent_executions = 50

  environment {
    variables = {
      MOODLE_BASE_URL = var.moodle_base_url
      IA_ENDPOINT     = var.ia_endpoint
      EVENT_BUS_NAME  = aws_cloudwatch_event_bus.eduverse.name
    }
  }

  tracing_config {
    mode = "Active"  # X-Ray habilitado (ADR-0001)
  }
}

resource "aws_lambda_event_source_mapping" "recommendation" {
  event_source_arn = aws_sqs_queue.recommendation_jobs.arn
  function_name    = aws_lambda_function.integrations.arn
  batch_size       = 10
}

###############################################################################
# IAM role minimo privilegio para o Lambda
###############################################################################

resource "aws_iam_role" "lambda_integrations" {
  name = "eduverse-lambda-integrations-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_integrations.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_integrations.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

###############################################################################
# Outputs
###############################################################################

output "rds_endpoint"      { value = aws_db_instance.main.endpoint        sensitive = true }
output "redis_endpoint"    { value = aws_elasticache_replication_group.main.primary_endpoint_address }
output "event_bus_name"    { value = aws_cloudwatch_event_bus.eduverse.name }
output "recommendation_q"  { value = aws_sqs_queue.recommendation_jobs.id }
