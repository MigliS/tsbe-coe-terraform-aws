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
  cidr_block                                  = ["172.16.0.0/24", "172.16.1.0/24", "172.16.2.0/24"][count.index]
  availability_zone                           = ["us-east-1a", "us-east-1b", "us-east-1c"][count.index]
  map_public_ip_on_launch                     = true
  enable_resource_name_dns_a_record_on_launch = true
  tags = {
    Name = "public_subnet-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = ["172.16.3.0/24", "172.16.4.0/24", "172.16.5.0/24"][count.index]
  availability_zone = ["us-east-1a", "us-east-1b", "us-east-1c"][count.index]
  tags = {
    Name = "private_subnet-${count.index}"
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
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.eks_public_rt.id
}

resource "aws_key_pair" "pxn" {
  key_name   = "pxn-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAJQDCWILY/F4kBFP4zQL2y3xAJ/H++71CAa4FtDOT9m8eVKS6fFTpurTJERjzdIE7EAsiA4z7FQyMo2kvyIzCX5/EGcYrINEwlkUghQqs+VY5ZFd2DgR7SYw5UP/FgZu+zKEybu6fsSUp7cU63WwPWd1tMZzEsYA1PN8ctGaqN1wDXq1JnrcD/TelYza+rFMadZGu+FBIkVSAcir0X8Rtnjl0qfdB1BjCgKp7irrSCuMTOzn6Wr6Pyk9veu3C1RWZCMFF6kUsWAUMR/qlG2flbvN3sAqwuoxoQ9rsH4NXbw7PRpyKJpcJ0ZQ8D6eAk+cb1lTyL2WHK1VpjohD/d5odvFHR588EZ2yLpVpu3ynkiYb2Ic0U9vkfUgf7FzFEWyqcR+v6VlpaM9qtkrEqKEx8/dUx4QEhON4Wy+zKnI5God/Veg3IQ8mUbEs9REgJl3zFCaNaqq/zFqh/Kn9w/R5Hxw9OIWpS2KglnsAwfeh97KHC0y3UdAQ/OnWoI7z88SJDGdhb5gkNTWsiWc+JbN6VVrvuK2jbWJuAyJyEgsNjTvc821C2ZdqRXcko0BVFVTFRZxxruTdHaLrVZJRdEb3t6mb48Rcwwb3KBNvgYaWCjX8JYA6VWiqHEs8LVDPsmeQakwKKP5dt9Oj63QCIb/dpBSNFIIAkaUbtz7W4daXIw== michael@fedora"
}

