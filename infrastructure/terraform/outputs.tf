output "vpc_id" {
  description = "ID of the WeatherOps VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in Availability Zone order."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs in Availability Zone order."
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID of the shared NAT gateway."
  value       = aws_nat_gateway.main.id
}

output "nat_public_ip" {
  description = "Elastic IPv4 address used for private subnet internet egress."
  value       = aws_eip.nat.public_ip
}

output "alb_security_group_id" {
  description = "Security group ID for the public Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "Security group ID for the private K3s instance."
  value       = aws_security_group.ec2.id
}

output "ec2_instance_profile_name" {
  description = "IAM instance profile name for the private K3s instance."
  value       = aws_iam_instance_profile.ec2.name
}

output "application_node_port" {
  description = "NodePort shared by the ALB target group and K3s Service."
  value       = var.application_node_port
}

output "ec2_instance_id" {
  description = "Instance ID for Session Manager and ALB target registration."
  value       = aws_instance.k3s.id
}

output "ec2_private_ip" {
  description = "Private IPv4 address of the future K3s node."
  value       = aws_instance.k3s.private_ip
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.public.dns_name
}

output "alb_arn" {
  description = "ARN of the public Application Load Balancer."
  value       = aws_lb.public.arn
}

output "alb_target_group_arn" {
  description = "ARN of the instance target group for the K3s NodePort."
  value       = aws_lb_target_group.k3s.arn
}
