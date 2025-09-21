project_name = "aws-2048-cicd-pipeline"
region       = "us-east-1"

codestar_connection_arn = "arn:aws:codestar-connections:us-east-1:123456789012:connection/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
github_owner            = "first-last"
github_repo             = "aws-2048-cicd-pipeline"
github_branch           = "main"

container_name = "2048-container"
image_name     = "2048-game"
container_port = 80

# optional: artifact_bucket_suffix = "123456789012"
