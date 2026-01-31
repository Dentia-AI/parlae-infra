data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "bastion_ssm_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion_ssm" {
  name               = "${local.project_id}-bastion-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.bastion_ssm_assume.json
  tags               = merge(local.tags_common, { Name = "${local.project_id}-bastion-ssm-role" })
}

resource "aws_iam_role_policy_attachment" "bastion_ssm_core" {
  role       = aws_iam_role.bastion_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${local.project_id}-bastion-profile"
  role = aws_iam_role.bastion_ssm.name
}

resource "aws_security_group" "bastion" {
  name        = "${local.project_id}-bastion-sg"
  description = "Security group for bastion host used for database access"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags_common, { Name = "${local.project_id}-bastion-sg" })
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.small" # Upgraded from t3.nano for stability
  subnet_id                   = tolist(values(aws_subnet.public))[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  # Prevent accidental termination
  disable_api_termination = false # Set to true in production for extra safety

  # Enable detailed monitoring
  monitoring = true

  # User data to ensure SSM agent is running and updated
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    
    # Update SSM Agent to latest version
    yum install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    
    # Keep instance alive and healthy
    echo "Bastion instance started successfully" > /var/log/bastion-init.log
  EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 20 # Increased from default 8GB
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(local.tags_common, {
    Name        = "${local.project_id}-bastion"
    Purpose     = "Database port forwarding via SSM"
    AutoRecover = "true"
  })

  lifecycle {
    ignore_changes = [ami] # Don't replace on AMI updates
  }
}

# CloudWatch alarm for auto-recovery if instance fails health checks
resource "aws_cloudwatch_metric_alarm" "bastion_auto_recover" {
  alarm_name          = "${local.project_id}-bastion-auto-recover"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Auto-recover bastion instance if system status checks fail"
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:recover"]

  dimensions = {
    InstanceId = aws_instance.bastion.id
  }

  tags = merge(local.tags_common, { Name = "${local.project_id}-bastion-auto-recover" })
}
