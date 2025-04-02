resource "aws_launch_template" "burst_node" {
  name_prefix   = "burst-node-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.ssh_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.burst_instance_profile.name
  }

  network_interfaces {
    security_groups = [aws_security_group.burst_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    haproxy_vip    = var.haproxy_vip
    wg_public_key  = var.wg_public_key
    wg_private_key = var.wg_private_key
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Role = "cloud-burst-node"
    }
  }
}

resource "aws_autoscaling_group" "burst_asg" {
  name                = "burst-asg-${var.environment}"
  min_size            = 0
  max_size            = 10
  desired_capacity    = 0
  vpc_zone_identifier = var.subnet_ids
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.burst_node.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.tags, {
      "AutoScalingGroup" = "cloud-burst-asg"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-policy"
  policy_type            = "StepScaling"
  autoscaling_group_name = aws_autoscaling_group.burst_asg.name

  step_adjustment {
    scaling_adjustment          = 2
    metric_interval_lower_bound = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "burst-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.burst_asg.name
  }
}
