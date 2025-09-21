# Project
variable "project_name" {
  type    = string
  default = "aws-2048-cicd-pipeline"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# GitHub via CodeConnections
variable "codestar_connection_arn" {
  type = string
}

variable "github_owner" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

# ECS/Container
variable "container_name" {
  type    = string
  default = "2048-container"
}

variable "image_name" {
  type    = string
  default = "2048-game"
}

variable "cpu" {
  type    = number
  default = 256
}

variable "memory" {
  type    = number
  default = 512
}

variable "container_port" {
  type    = number
  default = 80
}

# S3 artifacts bucket suffix (optional)
variable "artifact_bucket_suffix" {
  description = "Optional suffix for artifacts bucket; if empty, a random hex is used."
  type        = string
  default     = ""
}
