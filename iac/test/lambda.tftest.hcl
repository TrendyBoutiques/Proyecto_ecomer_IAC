# tests/lambda.tftest.hcl

variables {
  es_master_password          = "TestPassword123!" # CLAVE: Corrige el error de variable requerida
  environment                 = "test"
  project_name                = "iac-project"
  aws_region                  = "us-east-1"
  lambda_runtime              = "nodejs18.x"
  lambda_timeout              = 30
  lambda_memory_size          = 256
  log_level                   = "INFO"
  cloudwatch_log_retention_days = 7
}

# 4. Test para verificar que la función Lambda del catálogo existe
run "test_lambda_catalogo_service_exists" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_lambda_function.catalogo.arn != null
    error_message = "The 'catalogo' Lambda function was not created"
  }
}

# 5. Test para verificar el tiempo de espera (timeout) de la Lambda del catálogo
run "test_lambda_catalogo_timeout" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_lambda_function.catalogo.timeout == var.lambda_timeout
    error_message = "The 'catalogo' Lambda function timeout is not the expected value from var.lambda_timeout"
  }
}

# 6. Test para verificar que la Lambda está en la VPC privada
run "test_lambda_catalogo_in_vpc" {
  module {
    source = "../"
  }

  assert {
    # Verifica que la Lambda use una de las subredes privadas
    condition     = length(aws_lambda_function.catalogo.vpc_config[0].subnet_ids) > 0
    error_message = "The 'catalogo' Lambda is not configured in the private subnets"
  }
}

# 7. Test para verificar la variable de entorno de la tabla DynamoDB
run "test_lambda_catalogo_environment_variable" {
  module {
    source = "../"
  }

  assert {
    # Verifica que la variable 'PRODUCTS_TABLE' esté definida y no sea nula
    condition     = aws_lambda_function.catalogo.environment[0].variables.PRODUCTS_TABLE != null
    error_message = "The 'catalogo' Lambda is missing the PRODUCTS_TABLE environment variable"
  }
}