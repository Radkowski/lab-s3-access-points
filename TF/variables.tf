locals {
  user_data        = fileexists("./config.yaml") ? yamldecode(file("./config.yaml")) : jsondecode(file("./config.json"))
  REGION           = local.user_data.Parameters.Region
  VPCCIDR          = local.user_data.Parameters.VPCCIDR
  DEPLOYMENTPREFIX = local.user_data.Parameters.DeploymentPrefix
  BUCKETNAME       = local.user_data.Parameters.BucketName
  ADMINARN         = local.user_data.Parameters.AdminARN
  EC2KEYNAME       = local.user_data.Parameters.EC2KeyName
  EUAL             = local.user_data.Parameters.ExternalUserAccessList
  CREATEUSERS      = local.user_data.Parameters.CreateUsers
}


