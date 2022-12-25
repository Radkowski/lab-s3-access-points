data "aws_availability_zones" "AZs" {
  state = "available"
}


variable "DeploymentName" {}
variable "VPC_CIDR" {}




resource "aws_vpc" "RadLabVPC" {
  cidr_block                       = var.VPC_CIDR
  instance_tenancy                 = "default"
  enable_dns_hostnames             = "true"
  assign_generated_ipv6_cidr_block = "true"
  tags = {
    Name = "${var.DeploymentName}-VPC"
  }
}


resource "aws_subnet" "Pub-Dual-Subnet" {
  count                           = 2
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index)
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % 2]
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = true
  tags = {
    Name = join("", [var.DeploymentName, "-Pub-Dual-Sub"])
  }
}


resource "aws_subnet" "Priv-Dual-Subnet" {
  count                           = 2
  vpc_id                          = aws_vpc.RadLabVPC.id
  cidr_block                      = cidrsubnet(aws_vpc.RadLabVPC.cidr_block, 8, count.index + 2)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.RadLabVPC.ipv6_cidr_block, 8, count.index + 2)
  availability_zone               = data.aws_availability_zones.AZs.names[count.index % 2]
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = false
  tags = {
    Name = join("", [var.DeploymentName, "-Priv-Dual-Sub"])
  }
}


resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "IGW"])
  }
}


resource "aws_eip" "natgw_ip" {
  count      = 2
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = join("", [var.DeploymentName, "-NATGW-IP"])
  }
}


resource "aws_nat_gateway" "natgw" {
  count         = 2
  allocation_id = aws_eip.natgw_ip[count.index].id
  subnet_id     = aws_subnet.Pub-Dual-Subnet[count.index].id
  depends_on    = [aws_internet_gateway.igw, aws_eip.natgw_ip]
  tags = {
    Name = join("", [var.DeploymentName, "-NATGW"])
  }
}


resource "aws_egress_only_internet_gateway" "egw" {
  vpc_id = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-EIGW"])
  }
}


resource "aws_route_table" "PubRoute" {
  depends_on = [aws_vpc.RadLabVPC, aws_internet_gateway.igw]
  vpc_id     = aws_vpc.RadLabVPC.id
  tags = {
    Name = join("", [var.DeploymentName, "-Pub-RTable"])
  }
}


resource "aws_route" "pub1" {
  depends_on             = [aws_route_table.PubRoute]
  route_table_id         = aws_route_table.PubRoute.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "pub1_v6" {
  depends_on                  = [aws_route_table.PubRoute]
  route_table_id              = aws_route_table.PubRoute.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.igw.id
}


resource "aws_route_table" "PrivRoute" {
  count      = 2
  depends_on = [aws_vpc.RadLabVPC, aws_nat_gateway.natgw, aws_egress_only_internet_gateway.egw]
  vpc_id     = aws_vpc.RadLabVPC.id
  timeouts {
    create = "5m"
  }
  tags = {
    Name = join("", [var.DeploymentName, "-Priv-RTable-", count.index])
  }
}


resource "aws_route" "priv1" {
  count = 2
  timeouts {
    create = "5m"
  }
  depends_on             = [aws_route_table.PrivRoute, aws_nat_gateway.natgw]
  route_table_id         = aws_route_table.PrivRoute[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw[count.index].id
}

resource "aws_route" "priv2" {
  count = 2
  timeouts {
    create = "5m"
  }
  depends_on                  = [aws_route_table.PrivRoute, aws_egress_only_internet_gateway.egw]
  route_table_id              = aws_route_table.PrivRoute[count.index].id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.egw.id
}


resource "aws_route_table_association" "PubAssociation" {
  count          = 2
  subnet_id      = aws_subnet.Pub-Dual-Subnet[count.index].id
  route_table_id = aws_route_table.PubRoute.id
}


resource "aws_route_table_association" "PrivAssociation" {
  count          = 2
  subnet_id      = aws_subnet.Priv-Dual-Subnet[count.index].id
  route_table_id = aws_route_table.PrivRoute[count.index].id
}


output "VPCID" {
  value = aws_vpc.RadLabVPC.id
}

output "PUBSUBNETSID" {
  value = aws_subnet.Pub-Dual-Subnet
}

output "PRIVSUBNETSID" {
  value = aws_subnet.Priv-Dual-Subnet
}

output "ROUTETABLES" {
  value = concat(aws_route_table.PrivRoute[*].id, [aws_route_table.PubRoute.id])
}