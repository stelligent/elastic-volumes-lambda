provider "aws" {
  region = "us-east-1"
}

data "aws_iam_policy_document" "ev_demo_cloudwatch" {
  statement {
    sid = "1"

    actions = [
      "cloudwatch:PutMetricData",
       "cloudwatch:GetMetricStatistics",
       "cloudwatch:ListMetrics",
       "ec2:DescribeTags"
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "ev_demo_cloudwatch" {
  name   = "ev_demo_cloudwatch"
  policy = "${data.aws_iam_policy_document.ev_demo_cloudwatch.json}"
}

resource "aws_iam_role" "elastic_volumes_demo_role" {
  name = "elastic_volumes_demo_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "elastic_volumes_demo_profile" {
  name  = "elastic_volumes_demo_profile"
  role = "${aws_iam_role.elastic_volumes_demo_role.name}"
}

resource "aws_security_group" "elastic_volumes_demo_sg" {
  name        = "Elastic Volumes Demo SG"
  description = "Used for demo"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy_attachment" "ev_demo_attachment" {
  name       = "ev_demo_attachment"
  roles      = ["${aws_iam_role.elastic_volumes_demo_role.name}"]
  policy_arn = "${aws_iam_policy.ev_demo_cloudwatch.arn}"
}

resource "aws_instance" "jesse-ev-demo" {
  instance_type = "m3.medium"
  ami = "ami-c0c590d6"
  key_name = "jesse-labs"
  vpc_security_group_ids = ["${aws_security_group.elastic_volumes_demo_sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.elastic_volumes_demo_profile.name}"
  tags {
    Name = "jesse-ev-demo"
  }
}

resource "aws_sns_topic" "ev_demo_low_disk_space" {
  name = "ev_demo_low_disk_space"
}

resource "aws_cloudwatch_metric_alarm" "low_disk_space" {
  alarm_name                = "ev_demo_low_disk_space"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = "1"
  metric_name               = "DiskSpaceUtilization"
  namespace                 = "System/Linux"
  period                    = "300"
  statistic                 = "Average"
  threshold                 = "90"
  alarm_description         = "Kick off lambda to increase disk space if triggered"
  alarm_actions             = ["${aws_sns_topic.ev_demo_low_disk_space.arn}"]

  dimensions {
    InstanceId = "${aws_instance.jesse-ev-demo.id}",
    Filesystem = "/dev/xvda1",
    MountPath = "/"
  }
}

data "aws_iam_policy_document" "ev_demo_lambda" {
  statement {
    sid = "1"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid = "2"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:ModifyVolume"
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "ev_demo_lambda" {
  name   = "ev_demo_lambda"
  policy = "${data.aws_iam_policy_document.ev_demo_lambda.json}"
}

resource "aws_iam_role" "elastic_volumes_demo_role_lambda" {
  name = "elastic_volumes_demo_role_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "ev_demo_attachment_lambda" {
  name       = "ev_demo_attachment_lambda"
  roles      = ["${aws_iam_role.elastic_volumes_demo_role_lambda.name}"]
  policy_arn = "${aws_iam_policy.ev_demo_lambda.arn}"
}

resource "aws_lambda_function" "modify_elastic_volume" {
  filename         = "modify_elastic_volume.zip"
  function_name    = "modify_elastic_volume"
  role             = "${aws_iam_role.elastic_volumes_demo_role_lambda.arn}"
  handler          = "modify_elastic_volume.lambda_handler"
  source_code_hash = "${base64sha256(file("modify_elastic_volume.zip"))}"
  runtime          = "python2.7"
  timeout          = 30
}

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.modify_elastic_volume.function_name}"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.ev_demo_low_disk_space.arn}"
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = "${aws_sns_topic.ev_demo_low_disk_space.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.modify_elastic_volume.arn}"
}
