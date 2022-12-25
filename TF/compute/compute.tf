
data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-arm64-gp2"
}


variable "DeploymentName" {}
variable "VPCID" {}
variable "EC2KEYNAME" {}
variable "INSTPROF" {}



resource "aws_launch_template" "Launch-Template" {
  name                                 = join("", [var.DeploymentName, "-Launch-Template"])
  image_id                             = data.aws_ssm_parameter.ami.value
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t4g.medium"
  vpc_security_group_ids               = [aws_security_group.host-sg.id]
  key_name                             = var.EC2KEYNAME
  iam_instance_profile { name = var.INSTPROF.name }
  update_default_version = true
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
    }
  }
}


resource "aws_security_group" "host-sg" {
  name        = "ssh-only-sg"
  description = "Allow http(s)"
  vpc_id      = var.VPCID

  ingress = [
    {
      description      = "ssh traffic"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
  egress = [
    {
      description      = "Default rule"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]
}
