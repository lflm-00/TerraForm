terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.74.1"
    }
  }
}

provider "aws" {
  secret_key= "${var.secret_key}" 
  access_key = "${var.access_key}" 
  region  = "us-east-1"
}

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}