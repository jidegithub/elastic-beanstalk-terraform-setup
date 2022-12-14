# Configure AWS Credentials & Region
provider "aws" {
  profile = "${var.profile}"
  region  = "${var.region}"
}

#IAM Roles manage who has access to your AWS resources, 
#whereas IAM policies control their permissions. 
#A Role with no Policy attached to it won't have to access any AWS resources.


# S3 Bucket for storing Elastic Beanstalk task definitions
resource "aws_s3_bucket" "ng_beanstalk_deploys" {
  bucket = "${var.application_name}-deployments"
  force_destroy = true
  # lifecycle {
  #   # Any Terraform plan that includes a destroy of this resource will
  #   # result in an error message.
  #   prevent_destroy = true
  # }
  tags {
    Name        = "ebs-${var.application_name}"
    Environment = "${var.application_name}"
  }
}

# Elastic Container Repository for Docker images
resource "aws_ecr_repository" "ng_container_repository" {
  name = "${var.application_name}"
  force_delete = true
}

#iam ec2 instance service role for beanstalk instance
resource "aws_iam_role" "ng_beanstalk_ec2" {
  name = "ng-beanstalk-ec2-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Beanstalk instance profile
resource "aws_iam_instance_profile" "ng_beanstalk_ec2" {
  name  = "ng-beanstalk-ec2-user"
  role = "${aws_iam_role.ng_beanstalk_ec2.name}"
}

# Beanstalk EC2 Policy
# Overriding because by default Beanstalk does not have a permission to Read ECR
resource "aws_iam_role_policy" "ng_beanstalk_ec2_policy" {
  name = "ng_beanstalk_ec2_policy_with_ECR"
  role = "${aws_iam_role.ng_beanstalk_ec2.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "cloudwatch:PutMetricData",
        "ds:CreateComputer",
        "ds:DescribeDirectories",
        "ec2:DescribeInstanceStatus",
        "logs:*",
        "ssm:*",
        "ec2messages:*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages",
        "ecr:BatchGetImage",
        "s3:*",
        "elasticbeanstalk:PutInstanceStatistics"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# Beanstalk Application
resource "aws_elastic_beanstalk_application" "ng_beanstalk_application" {
  name        = "${var.application_name}"
  description = "${var.application_description}"
}

# Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "ng_beanstalk_application_environment" {
  name                = "${var.application_name}-${var.application_environment}"
  application         = "${aws_elastic_beanstalk_application.ng_beanstalk_application.name}"
  solution_stack_name = "64bit Amazon Linux 2 v3.4.19 running Docker"
  tier                = "WebServer"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"

    # Todo: As Variable
    value = "t2.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"

    # Todo: As Variable
    value = "2"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "${aws_iam_instance_profile.ng_beanstalk_ec2.name}"
  }
}