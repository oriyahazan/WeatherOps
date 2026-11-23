resource "aws_lb" "public" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  ip_address_type            = "ipv4"
  subnets                    = aws_subnet.public[*].id
  security_groups            = [aws_security_group.alb.id]
  enable_deletion_protection = var.alb_enable_deletion_protection

  depends_on = [aws_route_table_association.public]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "k3s" {
  name        = "${var.project_name}-k3s"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"
  protocol    = "HTTP"
  port        = var.application_node_port

  health_check {
    protocol = "HTTP"
    port     = "traffic-port"
    path     = "/healthcheck"
    matcher  = "200"
  }

  tags = {
    Name = "${var.project_name}-k3s"
  }
}

resource "aws_lb_target_group_attachment" "k3s" {
  target_group_arn = aws_lb_target_group.k3s.arn
  target_id        = aws_instance.k3s.id
}

resource "aws_lb_listener" "https" {
  count = trimspace(var.acm_certificate_arn) == "" ? 0 : 1

  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = trimspace(var.acm_certificate_arn)

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s.arn
  }
}
