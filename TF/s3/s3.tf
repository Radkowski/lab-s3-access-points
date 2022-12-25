variable "DEPLOYMENTPREFIX" {}
variable "BUCKETNAME" {}
variable "VPCID" {}
variable "ADMINARN" {}
variable "EUAL" {}
variable "INSTANCEPROFILEROLE" {}
variable "ROUTETABLES" {}



data "aws_caller_identity" "current" {}

data "aws_region" "current" {}


data "aws_iam_policy_document" "s3_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["*"]
    resources = [
      aws_s3_bucket.restricted_s3.arn,
      join("", [aws_s3_bucket.restricted_s3.arn, "/*"])
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:DataAccessPointAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
  statement {
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.restricted_s3.arn,
      join("", [aws_s3_bucket.restricted_s3.arn, "/*"])
    ]
    condition {
      test     = "StringNotEquals"
      variable = "s3:DataAccessPointAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalArn"
      values   = var.ADMINARN
    }
  }
}



resource "aws_s3_bucket" "restricted_s3" {
  bucket = lower(join("", [var.DEPLOYMENTPREFIX, "-", var.BUCKETNAME]))
}


resource "aws_s3_bucket" "unrestricted_s3" {
  bucket = lower(join("", ["insecure-",var.DEPLOYMENTPREFIX, "-", var.BUCKETNAME]))
}


resource "aws_s3_object" "upload_object_1" {
  bucket = aws_s3_bucket.restricted_s3.id
  key    = "testfile.txt"
  source = "${path.module}/testfile.txt"
}


resource "aws_s3_object" "upload_object_2" {
  bucket = aws_s3_bucket.unrestricted_s3.id
  key    = "testfile.txt"
  source = "${path.module}/testfile.txt"
}


resource "aws_s3_bucket_public_access_block" "block_pub_access" {
  bucket                  = aws_s3_bucket.restricted_s3.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


resource "aws_s3_access_point" "external_ap" {
  bucket = aws_s3_bucket.restricted_s3.id
  name   = lower(join("", [var.DEPLOYMENTPREFIX, "-external-ap"]))
}


resource "aws_s3_access_point" "internal_ap" {
  bucket = aws_s3_bucket.restricted_s3.id
  name   = lower(join("", [var.DEPLOYMENTPREFIX, "-internal-ap"]))
  vpc_configuration {
    vpc_id = var.VPCID
  }
}


resource "aws_s3_bucket_policy" "delegate_to_ap" {
  bucket = aws_s3_bucket.restricted_s3.id
  policy = data.aws_iam_policy_document.s3_policy.json
}


resource "aws_vpc_endpoint" "s3-endpoint" {
  vpc_id       = var.VPCID
  service_name = join("", ["com.amazonaws.", data.aws_region.current.name, ".s3"])
  tags = {
    Name = join("", [var.DEPLOYMENTPREFIX, "-s3-endpoint"])
  }
}


resource "aws_vpc_endpoint_route_table_association" "route-associations" {
  count        = length(var.ROUTETABLES)
  route_table_id  = var.ROUTETABLES[count.index]
  vpc_endpoint_id = aws_vpc_endpoint.s3-endpoint.id
}


resource "aws_vpc_endpoint_policy" "s3-endpoint-policy" {
  vpc_endpoint_id = aws_vpc_endpoint.s3-endpoint.id
  policy = jsonencode({
    "Version" : "2008-10-17",
    "Statement" : [{
      "Sid" : "AllowUseOfS3",
      "Effect" : "Allow",
      "Principal" : { "AWS" : "*" },
      "Action" : ["s3:Get*", "s3:List*"],
      "Resource" : "*"
      },
      {
        "Sid" : "OnlyIfAccessedViaAccessPoints",
        "Effect" : "Deny",
        "Principal" : { "AWS" : "*" },
        "Action" : "s3:*",
        "Resource" : "*",
        "Condition" : {
          "ArnNotLikeIfExists" : {
            "s3:DataAccessPointArn" : aws_s3_access_point.internal_ap.arn
          },
          "StringNotEquals" : {
            "aws:PrincipalArn" : var.INSTANCEPROFILEROLE.arn
          }
        }
      }
    ]
  })
}


resource "aws_s3control_access_point_policy" "internal_ap_policy" {
  access_point_arn = aws_s3_access_point.internal_ap.arn
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [{
      "Sid" : "Statement1",
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : var.INSTANCEPROFILEROLE.arn
      },
      "Action" : [
        "s3:Get*",
        "s3:List*"
      ],
      "Resource" : join("", [aws_s3_access_point.internal_ap.arn, "/object/*"])
      },
      {
        "Effect" : "Deny",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : "s3:*",
        "Resource" : [
          aws_s3_access_point.internal_ap.arn,
          join("", [aws_s3_access_point.internal_ap.arn, "/object/*"])
        ],
        "Condition" : {
          "StringNotEquals" : {
            "aws:PrincipalArn" : var.INSTANCEPROFILEROLE.arn
          }
        }
      }
    ]
  })
}



resource "aws_s3control_access_point_policy" "external_ap_policy" {
  access_point_arn = aws_s3_access_point.external_ap.arn
  policy = jsonencode({
    Version = "2008-10-17"
    Statement = [{
      "Effect" : "Allow",
      "Principal" : {
        "AWS" : var.EUAL
      },
      "Action" : [
        "s3:Get*",
        "s3:Put*",
        "s3:List*",
      ],
      "Resource" : join("", [aws_s3_access_point.external_ap.arn, "/object/*"])
      },
      {
        "Effect" : "Deny",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : "s3:*",
        "Resource" : [
          aws_s3_access_point.external_ap.arn,
          join("", [aws_s3_access_point.external_ap.arn, "/object/*"])
        ],
        "Condition" : {
          "StringNotEquals" : {
            "aws:PrincipalArn" : var.EUAL
          }
        }
      }
    ]
    }
  )
}





output "INTERNAL_AP" {
  value = aws_s3_access_point.internal_ap
}


output "EXTERNAL_AP" {
  value = aws_s3_access_point.external_ap
}

output "S3" {
  value = aws_s3_bucket.restricted_s3
}







