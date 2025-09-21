locals {
  name = var.project_name
  tags = { Project = var.project_name }
}

# Helpers
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------
# Default VPC + Subnets
# -----------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "allow_http" {
  name        = "${local.name}-allow-http"
  description = "Allow HTTP inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# -----------------------------
# ECR
# -----------------------------
resource "aws_ecr_repository" "repo" {
  name                 = "${local.name}-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = local.tags
}

# -----------------------------
# Logs
# -----------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 14
  tags              = local.tags
}

# -----------------------------
# ECS Cluster
# -----------------------------
resource "aws_ecs_cluster" "cluster" {
  name = "${local.name}-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = local.tags
}

# -----------------------------
# ECS Task Roles
# -----------------------------
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${local.name}-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "task_exec_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task_role" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.tags
}

# -----------------------------
# Task Definition (Fargate)
# -----------------------------
resource "aws_ecs_task_definition" "td" {
  family                   = "${local.name}-taskdef"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = "${aws_ecr_repository.repo.repository_url}:latest"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
        appProtocol   = "http"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.tags
}

# -----------------------------
# ECS Service (Public IP, no ALB)
# -----------------------------
resource "aws_ecs_service" "svc" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.td.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default_vpc.ids
    security_groups  = [aws_security_group.allow_http.id]
    assign_public_ip = true
  }

  # Allow CodePipeline to roll task defs without TF drift
  lifecycle { ignore_changes = [task_definition] }

  tags = local.tags
}

# -----------------------------
# S3 Artifacts Bucket
# -----------------------------
resource "random_id" "suffix" {
  byte_length = 3
}

locals {
  artifacts_bucket_name = var.artifact_bucket_suffix != "" ? "${local.name}-artifacts-${var.artifact_bucket_suffix}" : "${local.name}-artifacts-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "artifacts" {
  bucket        = local.artifacts_bucket_name
  force_destroy = true
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# CodeBuild (build + push)
# -----------------------------
data "aws_iam_policy_document" "cb_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name               = "${local.name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.cb_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "cb_inline" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }

  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRScoped"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:DescribeRepositories"
    ]
    resources = [aws_ecr_repository.repo.arn]
  }

  statement {
    sid     = "ArtifactsS3"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketAcl", "s3:GetBucketLocation"]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "codebuild_inline" {
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.cb_inline.json
}

resource "aws_codebuild_project" "build" {
  name         = "${local.name}-build"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    privileged_mode = true
    type            = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }

    environment_variable {
      name  = "ECR_REPO_URI"
      value = aws_ecr_repository.repo.repository_url
    }

    environment_variable {
      name  = "IMAGE_NAME"
      value = var.image_name
    }

    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.container_name
    }
  }

  source { type = "CODEPIPELINE" }

  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/codebuild/${local.name}"
      stream_name = "build"
    }
  }

  tags = local.tags
}

# -----------------------------
# CodePipeline (ECS deploy action)
# -----------------------------
data "aws_iam_policy_document" "cp_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${local.name}-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.cp_assume.json
  tags               = local.tags
}

# Final least-privilege policy for CodePipeline role (includes ECS tag permissions + cross-service reads)
data "aws_iam_policy_document" "cp_inline" {
  # S3 artifacts (scoped to your bucket)
  statement {
    sid     = "ArtifactsS3"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketAcl", "s3:GetBucketLocation"]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*"
    ]
  }

  # Start CodeBuild
  statement {
    sid       = "StartCodeBuild"
    effect    = "Allow"
    actions   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
    resources = [aws_codebuild_project.build.arn]
  }

  # Use GitHub connection
  statement {
    sid    = "UseGitHubConnection"
    effect = "Allow"
    actions = [
      "codeconnections:UseConnection",
      "codestar-connections:UseConnection"
    ]
    resources = [var.codestar_connection_arn]
  }

  # ECS read/list + task-def register + tag reads
  statement {
    sid       = "ECSReadAll"
    effect    = "Allow"
    actions   = ["ecs:Describe*", "ecs:List*", "ecs:ListTagsForResource"]
    resources = ["*"]
  }

  # Must be "*"
  statement {
    sid       = "ECSTaskDefRegister"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  # Tagging on task definitions/services during deploy
  statement {
    sid       = "ECSTagging"
    effect    = "Allow"
    actions   = ["ecs:TagResource", "ecs:UntagResource"]
    resources = ["*"]
  }

  # Update only your service
  statement {
    sid       = "ECSUpdateService"
    effect    = "Allow"
    actions   = ["ecs:UpdateService"]
    resources = [aws_ecs_service.svc.arn]
  }

  # Pass only your ECS task roles
  statement {
    sid     = "PassTaskRoles"
    effect  = "Allow"
    actions = ["iam:PassRole", "iam:GetRole", "iam:ListRoles", "iam:ListAttachedRolePolicies", "iam:GetPolicy", "iam:GetPolicyVersion"]
    resources = [
      aws_iam_role.task_execution.arn,
      aws_iam_role.task_role.arn
    ]
  }

  # ---- Extra read-only permissions ECS deploy often queries ----

  # Application Auto Scaling reads
  statement {
    sid       = "AppAutoScalingRead"
    effect    = "Allow"
    actions   = ["application-autoscaling:Describe*", "application-autoscaling:List*"]
    resources = ["*"]
  }

  # CloudWatch metric/alarms reads
  statement {
    sid    = "CloudWatchRead"
    effect = "Allow"
    actions = [
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:DescribeAlarms"
    ]
    resources = ["*"]
  }

  # Logs + ELB describes
  statement {
    sid    = "LogsAndELBRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "elasticloadbalancing:Describe*"
    ]
    resources = ["*"]
  }

  # EC2 networking describes
  statement {
    sid    = "EC2NetworkingRead"
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeRouteTables",
      "ec2:DescribeNetworkInterfaces"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codepipeline_inline" {
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.cp_inline.json
}

resource "aws_codepipeline" "pipeline" {
  name     = local.name
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "DockerBuildAndPush"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "ECSDeploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_output"]
      role_arn        = aws_iam_role.codepipeline.arn
      configuration = {
        ClusterName = aws_ecs_cluster.cluster.name
        ServiceName = aws_ecs_service.svc.name
        FileName    = "imagedefinitions.json"
      }
    }
  }

  tags = local.tags
}
