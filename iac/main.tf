terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
  backend "s3" {
    bucket = "terraform-state-proyecto-ecommerce" # EL NOMBRE DEL BUCKET QUE CREASTE
    key    = "terraform.tfstate"       # Nombre del archivo donde guardará la memoria
    region = "us-east-2"               # Tu región principal
  }
  # -------------------


provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "waf_region"
  region = "us-east-1"
}
