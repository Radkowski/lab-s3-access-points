
variable "DeploymentName" {}
variable "CREATEUSERS" {}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


resource "aws_iam_role" "instance-profile-role" {
  name = join("", [var.DeploymentName, "-ec2-role"])
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = join("", [var.DeploymentName, "-instance-profile-role"])
    policy = jsonencode({
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : ["s3:Get*", "s3:List*"],
          "Resource" : [
            join("", ["arn:aws:s3:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":accesspoint/", lower(join("", [var.DeploymentName, "-internal-ap"]))]),
            join("", ["arn:aws:s3:", data.aws_region.current.name, ":", data.aws_caller_identity.current.account_id, ":accesspoint/", lower(join("", [var.DeploymentName, "-internal-ap"])), "/object/*"])
          ]
        }
      ]
    })
  }
}


resource "aws_iam_instance_profile" "instance-profile" {
  name = join("", [var.DeploymentName, "-instance-profile"])
  role = aws_iam_role.instance-profile-role.name
}

resource "aws_iam_group" "s3-admins" {
  name = join("", [var.DeploymentName, "-s3-admin-groups"])
}

resource "aws_iam_group_policy_attachment" "group-policy" {
  group      = aws_iam_group.s3-admins.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_user" "test-users" {
  count = var.CREATEUSERS ? 3 : 0
  name  = join("", ["RadLab-s3-user-", count.index + 1])

}


# resource "aws_iam_access_key" "user_keys" {
#   count = var.CREATEUSERS ? 3 : 0
#   user    = aws_iam_user.test-users[count.index].name
#   }


resource "aws_iam_user_group_membership" "group-membership" {
  count = var.CREATEUSERS ? 3 : 0
  user  = aws_iam_user.test-users[count.index].name
  groups = [
    aws_iam_group.s3-admins.name,
  ]
}


output "EC2ROLE" {
  value = aws_iam_role.instance-profile-role
}

output "INSTPROF" {
  value = aws_iam_instance_profile.instance-profile
}

output "USERS" {
  value = [aws_iam_user.test-users[0].arn,aws_iam_user.test-users[1].arn]
}
