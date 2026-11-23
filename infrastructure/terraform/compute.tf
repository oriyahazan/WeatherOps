data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "k3s" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.private[0].id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-k3s-root"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data = <<-SCRIPT
    #!/bin/bash
    set -eu
    if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
      snap install amazon-ssm-agent --classic
    fi
    snap start --enable amazon-ssm-agent
  SCRIPT

  # Make the permissions and outbound HTTPS path available before first boot.
  depends_on = [
    aws_iam_role_policy_attachment.ec2_ssm,
    aws_route_table_association.private[0],
    aws_vpc_security_group_egress_rule.ec2_https,
  ]

  tags = {
    Name = "${var.project_name}-k3s"
  }
}
