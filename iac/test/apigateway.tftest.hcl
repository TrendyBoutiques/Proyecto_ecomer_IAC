# tests/apigateway.tftest.hcl

# Variables comunes necesarias para que el módulo compile
variables {
  es_master_password          = "TestPassword123!" # CLAVE: Corrige el error de variable requerida
  environment                 = "test"
  project_name                = "iac-project"
  cognito_user_pool_arn       = "arn:aws:cognito-idp:us-east-2:123456789012:userpool/us-east-2_abcdefgh"
  api_gateway_integration_timeout_ms = 29000
  enable_api_gateway_logging  = false
}

# 1. Test para asegurar que el API Gateway existe
run "test_api_gateway_exists" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_api_gateway_rest_api.main.id != null
    error_message = "The main REST API Gateway was not created"
  }
}

# 2. Test para asegurar la existencia de la integración de la Lambda 'card'
run "test_apigateway_lambda_integration" {
  module {
    source = "../"
  }

  assert {
    # Usa la clave de 'for_each' para encontrar la integración específica POST /card
    condition     = aws_api_gateway_integration.endpoint_integrations["card_POST"].id != null
    error_message = "API Gateway is missing the integration with the 'card_POST' method"
  }
}

# 3. Test para asegurar la existencia del Autorizador de Cognito
run "test_apigateway_cognito_authorizer" {
  module {
    source = "../"
  }

  assert {
    # Se usa el índice [0] porque 'aws_api_gateway_authorizer.cognito' tiene un 'count'
    condition     = aws_api_gateway_authorizer.cognito[0].id != null
    error_message = "API Gateway is missing the Cognito Authorizer"
  }
}