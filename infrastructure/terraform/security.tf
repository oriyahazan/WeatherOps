resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "Public HTTPS ingress and application traffic to the K3s node"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2"
  description = "Private K3s node with ALB-only ingress and web egress"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-ec2"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from the IPv4 internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ec2" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ec2.id
  description                  = "Application requests and health checks to the K3s NodePort"
  ip_protocol                  = "tcp"
  from_port                    = var.application_node_port
  to_port                      = var.application_node_port
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Application requests and health checks from the ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.application_node_port
  to_port                      = var.application_node_port
}

resource "aws_vpc_security_group_egress_rule" "ec2_https" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTPS for K3s downloads, Docker Hub, Systems Manager, and weather APIs"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "ec2_http" {
  security_group_id = aws_security_group.ec2.id
  description       = "HTTP for Ubuntu package repositories"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-ssm"
  role = aws_iam_role.ec2.name
}
