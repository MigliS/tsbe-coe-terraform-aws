provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "eks_vpc" {
  cidr_block           = "172.16.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "eks_vpc"
  }
}

resource "aws_subnet" "public" {
  count                                       = 3
  vpc_id                                      = aws_vpc.eks_vpc.id
  cidr_block                                  = ["172.16.0.0/24", "172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24", "172.16.4.0/24", "172.16.5.0/24"][count.index]
  availability_zone                           = ["us-east-1a", "us-east-1b", "us-east-1c"][count.index]
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  tags = {
    Name = "public_subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "eks_gw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks_gw"
  }
}

resource "aws_route_table" "eks_public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_gw.id
  }

  tags = {
    Name = "eks_public_rt"
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count          = length(aws_subnet.public.*.id)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.eks_public_rt.id
}

resource "aws_eip" "nat" {
  count  = length(aws_subnet.public.*.id)
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  count         = length(aws_subnet.public.*.id)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat_gateway-${count.index}"
  }
}


resource "aws_key_pair" "pxn" {
  key_name   = "pxn-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC00Ns/h8EY/TGMSpsSZ4NvniXtAEx2MlgH8ciFunmxNFqJWz+D50tm3V38OndkvuWXhxaVvHaDcslA5CosRB+mcnSLBW2z7QkA2LxtI4ClIUHTCk6IQ7yIDGYgJ3z3coeNdgBBxgIEF4tLGMx1ciXhK97fhk/Q093Cl3wkm/vCLN0kShBv7OZ4CqYF+0kAuflrjlhrNrlZQpW1CgHyJXxEPyZ98aXDabbISmq4XoltAe/zXBFV3fsNCzaS7nslKj6QqYLp1RHQXpaQ/qWCF4H18Z4uitk5TXTjVbqYOju+7i2FFN3NENHbzas1WkxH74n99+m7wPEsF7GFed+1zDbM7sG4PnZ9t1ke7sX/wBapHCTEUKrB+EtYs13CsBNS1wX7dZbXDgvduLcZahcnm9I1MrJbrqpLkdDMRJYgRAe3koFniM629XddM07JcRbNiDzBPMJbjl9RElwgHjl0CmYL9hRGM7SOVwISrCclR6tXk9hVWMSR61BAT8/DDx4TZ1c="
}

resource "aws_security_group" "eks_sg" {
  name        = "eks_cluster_sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks_cluster_sg"
  }
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "k8s-tf"
  role_arn = "arn:aws:iam::590184115564:role/LabRole"

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [
    aws_subnet.public,
    aws_route_table_association.public_subnet_asso
  ]
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "k8s-tf"
  node_role_arn   = "arn:aws:iam::590184115564:role/LabRole"
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}
