resource "aws_vpc" "pxn" {
  cidr_block       = "172.16.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "PXN-VPC"
  }
}

resource "aws_subnet" "public_subnets" {
 count      = length(var.public_subnet_cidrs)
 vpc_id     = aws_vpc.pxn.id
 cidr_block = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 map_public_ip_on_launch = true
 enable_resource_name_dns_a_record_on_launch = true
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}
 
resource "aws_subnet" "private_subnets" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.pxn.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}

resource "aws_internet_gateway" "gw" {
 vpc_id = aws_vpc.pxn.id
 
 tags = {
   Name = "PXN VPC IG"
 }
}

resource "aws_route_table" "public_rt" {
 vpc_id = aws_vpc.pxn.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.gw.id
 }
 
 tags = {
   Name = "Public Route Table"
 }
}

resource "aws_route_table_association" "public_subnet_asso" {
 count          = length(var.public_subnet_cidrs)
 subnet_id      = aws_subnet.public_subnets[count.index].id
 route_table_id = aws_route_table.public_rt.id
}

resource "aws_key_pair" "pxn" {
  key_name   = "pxn-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDUzfcqe1WBh79qtt59BF1LKgxhRHNK+7lv5FKEZB6zbmWhg+gNvucqcK6T0kTi9+0xguOh1hC6id2Gn/kaJocskRJNd58f8PUW3aaEVSVGzXm91dZ9cir7WswtzfwfiJneNRz+G1GvsZclE3YrniPKENSzrDynUAuiizYx/DrOyx5rFuPhWlxJgQviaVKXils/sC2FV5q9JltYXbzW0qCv7DgkamkjFAfx+36oiYAI72Hej/KZTdLIHvMzjt9XWhZAb4hGQZd0fqAugv4Y7xATnXhVA9VgaR/XG1FNexAp0JPriyPmxshhVoqmMREITc3N+PC0tNOyDpUpG0aX9l9M+AUVRyu5cmV+/HJaGirLKUISrg9Ox0U8VaHwmMOhizWRwq6cyGGSDXX2EePhzujVbOQ2fIFC4RXkpyKAuXj5euYoHmdT25bPLoTQWEhBpoIamtcZRgx7kE9iSU3jI5S61q+dvm2CELRwjxDJi19VM0LQ5rWJjHH3CmEThTB/lZ1+2jXB+co4pHMWD6brxjmj1lbFgn+hch1c0C3SBz9j5uVDJNvIaV+4TvsPNzuSWXP+BkD8k7yauUmPj7yYldqvNYZVlCdLKaTKV+BRO8Vpr1/TrXfG/LbFFj3IOfWpLq8/DHQnDEok0NbhgKJ2qVPA2V43dY2KNPGaOgYSvvzf1Q== pxn@pcpxn01"
}

resource "aws_security_group" "pxn_sg_ec2" {
  name        = "pxn_sg_ec2"
  description = "Allow SSH to PXN EC2"
  vpc_id      = aws_vpc.pxn.id

  # Ingress rule to allow TCP port 22 from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pxn_sg_ec2"
  }
}

resource "aws_instance" "pxn_ec2"{
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3a.micro"
  count         = 1
  subnet_id     = aws_subnet.public_subnets[0].id # Use the first subnet from the list (172.16.1.0/24)
  key_name      = aws_key_pair.pxn.key_name
  vpc_security_group_ids = [aws_security_group.pxn_sg_ec2.id]
  associate_public_ip_address = true # Enable public IP

  # root block device
  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

  tags = {
    Name = "PXN EC2 Instance"
  }
}



# Security Group for the RDS instance
resource "aws_security_group" "pxn_sg_rds" {
  name        = "pxn_sg_rds"
  description = "Allow access to RDS from EC2 instances and externally"
  vpc_id      = aws_vpc.pxn.id

  /*# Ingress rule to allow traffic from the EC2 security group
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.pxn_sg_ec2.id]
  }*/

  # To allow access from specific IP addresses or ranges, replace "0.0.0.0/0" with your IP/range
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pxn_sg_rds"
  }
}

# DB Subnet Group for the RDS instance
resource "aws_db_subnet_group" "pxn_db_subnet_group" {
  name       = "pxn-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]

  tags = {
    Name = "pxn-db-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "pxn_rds" {
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "15.5"
  instance_class       = "db.t3.micro"
  db_name              = "pxndb"
  username             = "pxnadmin"
  password             = "pxnadmin"
  
  db_subnet_group_name = aws_db_subnet_group.pxn_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.pxn_sg_rds.id]
  
  skip_final_snapshot  = true
  publicly_accessible  = true

  tags = {
    Name = "PXN RDS Instance"
  }
}