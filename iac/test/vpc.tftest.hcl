# tests/vpc.tftest.hcl

variables {
  es_master_password          = "TestPassword123!" # CLAVE: Corrige el error de variable requerida
  environment                 = "test"
  project_name                = "iac-project"
  vpc_cidr                    = "10.0.0.0/16"
  public_subnets_cidr         = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr        = ["10.0.101.0/24", "10.0.102.0/24"]
}

# 12. Test para validar la existencia del VPC
run "vpc_module_validation" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_vpc.main.id != null
    error_message = "VPC ID should not be null"
  }
}

# 13. Test para la cuenta de subredes públicas
run "test_public_subnets_count" {
  module {
    source = "../"
  }

  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "There should be 2 public subnets"
  }
}

# 14. Test para la cuenta de subredes privadas
run "test_private_subnets_count" {
  module {
    source = "../"
  }

  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "There should be 2 private subnets"
  }
}

# 15. Test para asegurar la existencia del Security Group para Lambdas
run "test_lambda_security_group_exists" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_security_group.lambda.id != null
    error_message = "Lambda security group ID should not be null"
  }
}