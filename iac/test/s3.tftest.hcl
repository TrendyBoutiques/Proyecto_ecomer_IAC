# tests/s3.tftest.hcl

variables {
  es_master_password          = "TestPassword123!" # CLAVE: Corrige el error de variable requerida
  environment                 = "test"
  project_name                = "iac-project"
}

# 8. Test para verificar la creación y salidas del S3
run "test_s3_bucket_creation_and_outputs" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_s3_bucket.website.bucket != null
    error_message = "S3 bucket name should not be null"
  }

  assert {
    condition     = aws_s3_bucket.website.arn != null
    error_message = "S3 bucket ARN should not be null"
  }
}

# 9. Test para verificar que el bucket tiene versión habilitada
run "test_s3_versioning_enabled" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_s3_bucket_versioning.website.status == "Enabled"
    error_message = "S3 bucket versioning must be enabled for safety"
  }
}

# 10. Test para asegurar que el bucket NO permite acceso público
run "test_s3_public_access_blocked" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.website.block_public_acls == true
    error_message = "S3 bucket public ACLs must be blocked as per configuration"
  }
}

# 11. Test para verificar que el tag de entorno exista
run "test_s3_environment_tag" {
  module {
    source = "../"
  }

  assert {
    condition     = aws_s3_bucket.website.tags.Environment == var.environment
    error_message = "S3 bucket must have the correct 'Environment' tag"
  }
}