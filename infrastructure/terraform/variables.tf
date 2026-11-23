variable "aws_region" {
  description = "AWS region for the WeatherOps network."
  type        = string
  default     = "il-central-1"
  nullable    = false
}

variable "project_name" {
  description = "Project name used for resource names and tags."
  type        = string
  default     = "weatherops"
  nullable    = false
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Provide an IPv4 CIDR block for the VPC."
  }
}

variable "public_subnet_cidrs" {
  description = "Two public IPv4 CIDR blocks in Availability Zone order."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  nullable    = false

  validation {
    condition     = length(var.public_subnet_cidrs) == 2 && alltrue([for cidr in var.public_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Provide two public IPv4 CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  description = "Two private IPv4 CIDR blocks in Availability Zone order."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
  nullable    = false

  validation {
    condition     = length(var.private_subnet_cidrs) == 2 && alltrue([for cidr in var.private_subnet_cidrs : can(cidrnetmask(cidr))])
    error_message = "Provide two private IPv4 CIDR blocks."
  }
}

variable "availability_zones" {
  description = "Two Availability Zones in the configured region. The first hosts the NAT gateway."
  type        = list(string)
  default     = ["il-central-1a", "il-central-1b"]
  nullable    = false

  validation {
    condition = (
      length(var.availability_zones) == 2 &&
      length(distinct(var.availability_zones)) == 2 &&
      alltrue([for zone in var.availability_zones : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+[a-z]$", zone)) && try(substr(zone, 0, length(zone) - 1) == var.aws_region, false)])
    )
    error_message = "Provide two distinct regional Availability Zones in the configured AWS region."
  }
}

variable "application_node_port" {
  description = "TCP NodePort for the ALB instance target group and its health checks."
  type        = number
  default     = 30080
  nullable    = false

  validation {
    condition     = var.application_node_port >= 30000 && var.application_node_port <= 32767 && floor(var.application_node_port) == var.application_node_port
    error_message = "Provide an integer NodePort between 30000 and 32767."
  }
}

variable "ec2_instance_type" {
  description = "An x86_64 EC2 instance type available in the first private subnet's Availability Zone."
  type        = string
  default     = "t3.medium"
  nullable    = false
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for the public Application Load Balancer."
  type        = bool
  default     = false
  nullable    = false
}

variable "acm_certificate_arn" {
  description = "ARN of an issued ACM certificate in the ALB region. Leave blank to omit the HTTPS listener."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition = (
      trimspace(var.acm_certificate_arn) == "" ||
      can(regex("^arn:aws:acm:${var.aws_region}:[0-9]{12}:certificate/[0-9a-fA-F-]+$", trimspace(var.acm_certificate_arn)))
    )
    error_message = "Provide an ACM certificate ARN in the configured AWS region, or leave it blank."
  }
}
