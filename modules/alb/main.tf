# Public ALB with path-based routing:
#   /auth/*, /images/*, /internal/*  -> backend target group (NestJS API)
#   /*                               -> frontend target group (Next.js)
# Path routing was chosen over subdomains because no domain is provisioned
# for this dev environment (no Route53 zone, no ACM cert yet); the paths map
# 1:1 to the backend's controllers (@Controller('auth'|'images'|'internal'))
# and the frontend's pages (/login, /records, /upload) don't collide with them.
# When a domain arrives: add an ACM cert + 443 listener and switch
# NEXT_PUBLIC_API_URL/CORS_ORIGIN to https — no infra rework required.

# ---------------- Target groups ----------------

# Frontend target group REMOVED — the frontend is static now
# (S3 + CloudFront); the ALB serves only the backend API.

resource "aws_lb_target_group" "backend" {
  name     = "${var.name_prefix}-backend"
  port     = var.backend_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  target_type = var.target_type

  # The API has no unauthenticated health endpoint; any auth-protected route
  # answers 401 within seconds, which proves the process is up. 2xx-4xx is
  # the honest health matcher until a dedicated /healthz endpoint is added.
  health_check {
    enabled             = true
    path                = "/images"
    protocol            = "HTTP"
    matcher             = "200-499"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
  }

  # Realtime gateway (Socket.IO websockets) — keep connections sticky-free
  # (single instance) but long-lived.
  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-backend"
  })
}

# Target registration is owned by the ECS services (load_balancer blocks) —
# no static instance attachments here anymore.

# ---------------- ALB ----------------

resource "aws_lb" "main" {
  name               = var.name_prefix
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true

  tags = merge(var.tags, {
    Name = var.name_prefix
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default: the backend catches everything (the frontend is static on
  # S3 + CloudFront and no longer goes through this ALB).
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-http"
  })
}

resource "aws_lb_listener_rule" "backend_auth" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/auth/*", "/auth"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_images" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/images/*", "/images"]
    }
  }
}

resource "aws_lb_listener_rule" "backend_internal" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/internal/*", "/internal"]
    }
  }
}

# Socket.IO realtime gateway: the browser's websocket handshake goes to
# /socket.io/* (long-polling handshake first, then the ws upgrade). Without
# this rule those requests fall through to the default frontend rule and
# the connection never reaches the backend's gateway. The ALB forwards
# websocket upgrades natively — no extra listener config needed.
resource "aws_lb_listener_rule" "backend_socketio" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 40

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/socket.io/*", "/socket.io"]
    }
  }
}