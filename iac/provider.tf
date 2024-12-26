terraform {
  required_version = ">= 1.0.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~>2.20.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Estos valores deben ser proporcionados durante terraform init
    bucket         = "terraform-state-375943871844"
    region         = "eu-west-1"
    key            = "terraform.tfstate"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

provider "docker" {}

provider "aws" {
  region = var.aws_region
}