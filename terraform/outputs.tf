output "ecr_repository_url" {
  value       = aws_ecr_repository.repo.repository_url
  description = "Use as <your-ecr-repository-uri> in buildspec.yml"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.svc.name
}

output "container_name" {
  value       = var.container_name
  description = "Use as <container-name> in buildspec.yml"
}

output "image_name" {
  value       = var.image_name
  description = "Local Docker tag used in buildspec.yml"
}

output "artifact_bucket" {
  value       = aws_s3_bucket.artifacts.bucket
  description = "Pipeline/Build artifacts bucket"
}

output "pipeline_name" {
  value = aws_codepipeline.pipeline.name
}

output "security_group_id" {
  value = aws_security_group.allow_http.id
}
