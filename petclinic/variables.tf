variable "AWS_REGION" {    
    default = "us-east-1"
}

variable "public_subnet_cidrs" {
 type        = list(string)
 description = "Public Subnet CIDR values"
 default     = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
}
 
variable "private_subnet_cidrs" {
 type        = list(string)
 description = "Private Subnet CIDR values"
 default     = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24", "172.16.7.0/24", "172.16.8.0/24", "172.16.9.0/24"]
}

variable "azs" {
 type        = list(string)
 description = "Availability Zones"
 default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}