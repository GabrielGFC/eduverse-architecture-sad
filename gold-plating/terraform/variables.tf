variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "dev | staging | prod"
  type        = string
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.medium"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "ecr_registry" {
  description = "URL do ECR (ex: 123456789012.dkr.ecr.us-east-1.amazonaws.com)"
  type        = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "lambda_zip" {
  description = "Caminho do bundle do integrations-service"
  type        = string
  default     = "../../src/integrations-service/dist/bundle.zip"
}

variable "moodle_base_url" {
  type = string
}

variable "ia_endpoint" {
  type = string
}
