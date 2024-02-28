resource "aws_vpc" "pxn" {
  cidr_block       = "172.16.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

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
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAJQDCWILY/F4kBFP4zQL2y3xAJ/H++71CAa4FtDOT9m8eVKS6fFTpurTJERjzdIE7EAsiA4z7FQyMo2kvyIzCX5/EGcYrINEwlkUghQqs+VY5ZFd2DgR7SYw5UP/FgZu+zKEybu6fsSUp7cU63WwPWd1tMZzEsYA1PN8ctGaqN1wDXq1JnrcD/TelYza+rFMadZGu+FBIkVSAcir0X8Rtnjl0qfdB1BjCgKp7irrSCuMTOzn6Wr6Pyk9veu3C1RWZCMFF6kUsWAUMR/qlG2flbvN3sAqwuoxoQ9rsH4NXbw7PRpyKJpcJ0ZQ8D6eAk+cb1lTyL2WHK1VpjohD/d5odvFHR588EZ2yLpVpu3ynkiYb2Ic0U9vkfUgf7FzFEWyqcR+v6VlpaM9qtkrEqKEx8/dUx4QEhON4Wy+zKnI5God/Veg3IQ8mUbEs9REgJl3zFCaNaqq/zFqh/Kn9w/R5Hxw9OIWpS2KglnsAwfeh97KHC0y3UdAQ/OnWoI7z88SJDGdhb5gkNTWsiWc+JbN6VVrvuK2jbWJuAyJyEgsNjTvc821C2ZdqRXcko0BVFVTFRZxxruTdHaLrVZJRdEb3t6mb48Rcwwb3KBNvgYaWCjX8JYA6VWiqHEs8LVDPsmeQakwKKP5dt9Oj63QCIb/dpBSNFIIAkaUbtz7W4daXIw== michael@fedora"
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

  # Ingress rule to allow TCP port 8080 from anywhere
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pxn_sg_ec2"
  }
}

resource "aws_instance" "pxn_ec2"{
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t3a.large"
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

  user_data = <<-EOT
    #!/bin/bash
    sudo apt install openjdk-17-jdk -y
    sudo echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> ~/.bashrc
    source ~/.bashrc

    cd /opt && git clone https://github.com/spring-projects/spring-petclinic.git
    cd /opt/spring-petclinic
    ./mvnw package

    # Create application.properties file from Terraform template
    sudo cat <<EOF > /opt/spring-petclinic/src/main/resources/application.properties
    ${templatefile("${path.module}/application.properties.tpl", {
      db_endpoint = aws_db_instance.pxn_rds.endpoint
    })}
    EOF

    nohup java -jar target/*.jar > /tmp/petclinic.log 2>&1 &
  EOT
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
  db_name              = "petclinic"
  username             = "petclinic"
  password             = "petclinic"
  
  db_subnet_group_name = aws_db_subnet_group.pxn_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.pxn_sg_rds.id]
  
  skip_final_snapshot  = true
  publicly_accessible  = true

  tags = {
    Name = "PXN RDS Instance"
  }
}
