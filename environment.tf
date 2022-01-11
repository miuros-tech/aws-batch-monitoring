data "aws_ami" "ecs" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["897127263736"]
}

resource "aws_launch_template" "compute_template" {
  name = "test-ce-01"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 50
      encrypted   = true
    }
  }

  image_id = data.aws_ami.ecs.id

  vpc_security_group_ids = [
    aws_security_group.batch.id,
  ]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test-ce-01"
      Function = "Batch"
    }
  }

  user_data = base64encode(templatefile("${path.module}/compute_init", {
    node_exporter_version = "1.2.2",
    cadvisor_version      = "v0.40.0",
    node_exporter_service = filebase64("${path.module}/prometheusNode.service")
  }))
}

resource "aws_batch_compute_environment" "main" {
  compute_environment_name = "test-ce-02"

  compute_resources {
    instance_role = aws_iam_instance_profile.ecs_instance_role.arn

    launch_template {
      launch_template_id = aws_launch_template.compute_template.id
    }

    instance_type = [
      "optimal",
    ]
    allocation_strategy = "BEST_FIT"

    max_vcpus = 128
    min_vcpus = 0

    security_group_ids = [
      aws_security_group.batch.id,
    ]

    subnets = [aws_subnet.main.id]
    type    = "EC2"
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"

}

resource "aws_batch_job_queue" "main" {
  depends_on = [
    aws_batch_compute_environment.main
  ]
  name     = "test-jq-01"
  state    = "ENABLED"
  priority = 1
  compute_environments = [
    aws_batch_compute_environment.main.arn,
  ]
}
