variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "eu-west-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "The CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ip" {
  description = "IP address allowed to access restricted services"
  type        = string
  default     = "81.41.129.51/32"  # Cambiar esto a tu IP por defecto
}