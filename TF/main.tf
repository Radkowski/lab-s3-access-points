module "IAM" {
  source         = "./iam"
  DeploymentName = local.DEPLOYMENTPREFIX
  CREATEUSERS    = local.CREATEUSERS
}

module "NETWORK" {
  source         = "./network"
  DeploymentName = local.DEPLOYMENTPREFIX
  VPC_CIDR       = local.VPCCIDR
}


module "COMPUTE" {
  depends_on     = [module.NETWORK, module.IAM]
  source         = "./compute"
  DeploymentName = local.DEPLOYMENTPREFIX
  VPCID          = module.NETWORK.VPCID
  EC2KEYNAME     = local.EC2KEYNAME
  INSTPROF       = module.IAM.INSTPROF
}


module "S3" {
  depends_on          = [module.NETWORK, module.COMPUTE]
  source              = "./s3"
  DEPLOYMENTPREFIX    = local.DEPLOYMENTPREFIX
  BUCKETNAME          = local.BUCKETNAME
  VPCID               = module.NETWORK.VPCID
  ADMINARN            = local.ADMINARN
  EUAL                = local.CREATEUSERS ? module.IAM.USERS : local.EUAL
  INSTANCEPROFILEROLE = module.IAM.EC2ROLE
  ROUTETABLES         = module.NETWORK.ROUTETABLES
}



output "INTERNAL_AP" {
  value = module.S3.INTERNAL_AP.alias
}


output "EXTERNAL_AP" {
  value = module.S3.EXTERNAL_AP.alias
}

output "S3" {
  value = join("", ["s3://", module.S3.S3.bucket])
}

