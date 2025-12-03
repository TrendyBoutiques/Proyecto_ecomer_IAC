terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
  backend "s3" {
    bucket = "terraform-state-proyecto-ecommerce"
    key    = "terraform.tfstate"       
    region = "us-east-2"               
  }



provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "waf_region"
  region = "us-east-1"
}
