# 2048 Game CI/CD Pipeline
A cloud-native project that demonstrates how to implement a **continuous integration and continuous delivery (CI/CD) pipeline** on AWS. The application is the classic **2048 Game**, containerized with Docker and deployed on **Amazon ECS** using **AWS Fargate**.  

This pipeline automatically builds and deploys updates whenever code is pushed to GitHub. The infrastructure leverages **Terraform** for reproducibility and Infrastructure-as-Code best practices. The application runs in the **default VPC and subnets**, making the setup straightforward without custom networking.  

## Architecture Overview
![Architecture Diagram](assets/architecture-diagram.png)  
*Figure 1: Architecture diagram of the 2048 Game CI/CD Pipeline.*  

- **Amazon ECR** – Stores Docker images for the 2048 application.  
- **Amazon ECS (Fargate)** – Runs the containerized application serverlessly.  
- **AWS CodePipeline** – Orchestrates the end-to-end CI/CD workflow.  
- **AWS CodeBuild** – Builds Docker images, tags them, and pushes them to ECR.  
- **AWS CodeDeploy** – Updates ECS services with new container images.  
- **Amazon S3** – Stores pipeline artifacts such as `imagedefinitions.json`.  
- **AWS CloudWatch Logs** – Captures application and build logs for monitoring.  
- **AWS IAM** – Manages least-privilege roles and policies for ECS, CodeBuild, and CodePipeline.  

## Skills Applied
- Automating a **GitHub-triggered CI/CD pipeline** with AWS CodePipeline.  
- Containerizing the **2048 game application** using Docker.  
- Deploying workloads on **Amazon ECS with Fargate** to eliminate server management.  
- Managing container images with a private **Amazon ECR repository**.  
- Scoping IAM roles and policies to enforce **least-privilege access** for pipeline, ECS tasks, and builds.  
- Enabling **CloudWatch Logs** for centralized monitoring of ECS tasks and CodeBuild.  

## Features
- **Fully automated pipeline** – From GitHub commit → Build → Deploy to ECS.  
- **Serverless containers** – Application runs on **ECS Fargate** with no EC2 management.  
- **Immutable builds** – Each Git push generates a new Docker image in ECR.  
- **Scalable architecture** – ECS service can be scaled by adjusting desired task count.  
- **Cross-service integration** – Seamless orchestration across ECR, ECS, S3, CodeBuild, and CodePipeline.  

## Tech Stack
- **Languages:** Dockerfile
- **AWS Services:** CodePipeline, CodeBuild, CodeDeploy, ECS (Fargate), ECR, S3, IAM, CloudWatch  
- **IaC Tool:** Terraform  
- **Other Tools:** GitHub, Docker, AWS CLI  

## Deployment Instructions
> **Note:** All command-line examples use `bash` syntax highlighting to maximize compatibility and readability. If you are using PowerShell or Command Prompt on Windows, the commands remain the same but prompt styles may differ.  

1. Clone this repository.  

2. Create a new repository in GitHub and push `2048-game` folder to it using Git:  
   ```bash
   cd 2048-game
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin git@github.com:<your-username>/<repository-name>.git
   git branch -M main
   git push -u origin main
   ```

3. In AWS Developer Tools > Connections, create a CodeConnection to GitHub and authorize the repository.  

4. Create the IAM Role for ECS `AWSServiceRoleForECS` if it does not exist.  

- **Windows (PowerShell):**  
     ```powershell
	try {
    	aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
	} catch {
    	Write-Host "Service-linked role already exists, continuing..."
	}
	```

- **Linux:**  
     ```bash
     aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com || true
     ```

### Terraform
5. Edit variables in `terraform.tfvars` and/or `variables.tf` to customize the deployment.  

6. Navigate to the `terraform` folder and deploy:  
   ```bash
   cd terraform
   terraform init
   terraform plan # Optional, but recommended.
   terraform apply
   ```  
   
7. *(Optional)* Edit the files in the `2048-game` directory and push them using Git. The CodePipeline will automatically deploy a new ECS task.  
 
**Note:** Ensure the AWS CLI is configured (`aws configure`) with credentials that have sufficient permissions to manage **S3**, **ECS/ECR resources**, **CodeBuild/CodeDeploy/CodePipeline resources**, **CloudWatch Logs**, **Security Groups**, and **IAM resources**.  

## How to Use
1. **Deploy the infrastructure** using Terraform.  

2. **Access the application** in a web browser via the ECS Task Public IP address:  
	```plaintext
	http://<ECS Task Public IP Address>
	```
3. Use the **arrow keys** to move the tiles. Tiles with the same number merge into one when they touch. Add them up to reach 2048.  

## Project Structure
```plaintext
aws-2048-game-cicd-pipeline
├── 2048-game/                    		  # 2048 game source code
│   ├── buildspec.yaml			          # Build specification reference
│   └── Dockerfile        				  # Dockerfile
├── assets/                          	  # Images, diagrams, screenshots
│   ├── architecture-diagram.png          # Project architecture diagram
│   └── application-screenshot.png        # UI screenshot
├── terraform/                   		  # Terraform templates
│   ├── main.tf                     	  # Main Terraform config
│   ├── variables.tf                      # Input variables
│   ├── outputs.tf						  # Exported values
│   ├── terraform.tfvars            	  # Default variable values
│   ├── providers.tf			    	  # AWS provider definition
│   └── versions.tf						  # Terraform version constraint
├── LICENSE
├── README.md
└── .gitignore
```  

## Screenshot
![2048 Game](assets/application-screenshot.png)  

*Figure 2: 2048 Game Application UI deployed on ECS Fargate.*  

## Future Enhancements
- **CI/CD Testing Phase**: Add automated test stage in CodePipeline before deploy.  
- **Custom VPC & Networking**: Use private subnets, NAT gateway, and ALB for production-grade architecture.  
- **Scaling Policies** : Enable **ECS Service Auto Scaling** via CloudWatch alarms.  
- **Monitoring Dashboard**: Add **CloudWatch Dashboards** and **Alarms** for observability.  
- **HTTPS Support**: Integrate **Application Load Balancer + ACM SSL certificate** for secure access.  

## License
This project is licensed under the [MIT License](LICENSE).  

---

## Author
**Patrick Heese**  
Cloud Administrator | Aspiring Cloud Engineer/Architect  
[LinkedIn Profile](https://www.linkedin.com/in/patrick-heese/) | [GitHub Profile](https://github.com/patrick-heese)  

## Acknowledgments
This project was inspired by a course from [techwithlucy](https://github.com/techwithlucy).  
The 2048 game application code is taken directly from the author’s original implementation. The `buildspec.yml` file was edited to include variables for portability.  
The architecture diagram included here is my own version, adapted from the original course diagram.  
I designed and developed all Infrastructure-as-Code (CloudFormation, SAM, Terraform) and project documentation.  
