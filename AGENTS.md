# WeatherOps — Codex Agent Instructions

## Project Overview
WeatherOps is a DevOps portfolio project built around a FastAPI weather application.

The goal is to demonstrate practical DevOps engineering skills using Docker, Kubernetes, Helm, GitHub Actions, AWS, Terraform, Ansible, Argo CD, and monitoring tools.

## Technology Stack
- Application: Python 3.12, FastAPI, HTML, CSS, JavaScript
- Testing: pytest, HTTPX
- Containerization: Docker
- Kubernetes: Minikube (local), K3s (AWS)
- Package Management: Helm
- CI: GitHub Actions
- Container Registry: Docker Hub (`oriyahazan/weatherops`)
- Infrastructure: AWS, Terraform
- Configuration Management: Ansible
- CD: Argo CD (planned)
- Monitoring: Prometheus and Grafana (planned)

## Approved AWS Architecture
- Region: `il-central-1`
- VPC with public and private subnets
- Internet Gateway and one NAT Gateway
- Internet-facing Application Load Balancer
- One Ubuntu EC2 instance in a private subnet
- Single-node K3s cluster
- AWS Systems Manager Session Manager for administration
- No public SSH or Kubernetes API access
- HTTPS for public application access

## General Working Rules
1. Inspect relevant existing files before making changes.
2. Make minimal, focused changes for the requested task.
3. Preserve existing application behavior and repository conventions.
4. Do not modify unrelated files.
5. Explain important technical decisions and trade-offs.
6. Prefer simple, maintainable, production-inspired solutions over unnecessary complexity.
7. Validate changes using appropriate local commands.
8. Report files changed, validation results, and remaining issues.

## AWS and Terraform Safety
1. NEVER run `terraform apply` or `terraform destroy` without explicit user approval.
2. NEVER create, modify, or delete AWS resources without explicit user approval.
3. Do not perform any AWS operation that may incur charges without explicit approval.
4. Terraform `fmt`, `init -backend=false`, `validate`, and `plan` are allowed when appropriate, provided they do not modify AWS resources.
5. Do not use `terraform plan` with automatic infrastructure changes or apply flags.
6. Prefer least-privilege IAM and restrictive Security Groups.
7. Never expose SSH (22) or Kubernetes API (6443) publicly.
8. Never store credentials, secrets, private keys, or sensitive Terraform state in Git.
9. Do not automatically commit or push changes.
10. Before proposing infrastructure deployment, explain expected costs and potential risks.

## Ansible Safety
1. Do not execute playbooks against remote servers without explicit approval.
2. Prefer idempotent playbooks and reusable roles.
3. Do not store secrets or credentials in playbooks or inventory files.
4. Use AWS Systems Manager for server access where feasible.
5. Do not install or modify software on AWS instances without approval.

## Kubernetes and Deployment
1. Use Helm for WeatherOps application deployment.
2. Preserve the existing local Minikube configuration unless changes are explicitly requested.
3. Prefer immutable Docker image tags based on Git commit SHA.
4. Do not perform live deployments without approval.
5. Argo CD will be introduced in a later project stage.

## Validation and Reporting
After each task:
- Summarize what changed and why.
- List created or modified files.
- Report validation commands and results.
- Identify any assumptions or unresolved issues.
- Confirm whether any AWS resources were affected.

## Git Rules
- Never commit, push, reset, or discard user changes without explicit approval.
- Do not overwrite unrelated work.
- Keep changes scoped to the current task.
