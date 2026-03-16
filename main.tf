terraform {
  backend "s3" {
    bucket = "group3-terraform-state-unique-id"
    key    = "state/terraform.tfstate"
    region = "us-east-1"
  }
}

# --- 1. PROVISION THE ECR REPOSITORY ---
resource "aws_ecr_repository" "rekognition_repo" {
  name                 = "group3-rekognition-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true 
}

# --- 2. SECURITY ROLES (IAM) ---
resource "aws_iam_role" "lambda_exec_role" {
  name = "group3_rekognition_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_rekognition" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRekognitionFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# --- 3. S3 BUCKETS (INPUT, OUTPUT, WEB) ---
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "image_inputs" {
  bucket = "group3-rekognition-inputs-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "analysis_outputs" {
  bucket = "group3-rekognition-outputs-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "web_ui" {
  bucket = "group3-ai-dashboard-${random_id.suffix.hex}"
}

# Enable Static Website Hosting
resource "aws_s3_bucket_website_configuration" "web_config" {
  bucket = aws_s3_bucket.web_ui.id
  index_document { suffix = "index.html" }
}

# Public Access Configuration for Web Bucket
resource "aws_s3_bucket_public_access_block" "web_access" {
  bucket = aws_s3_bucket.web_ui.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.web_ui.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.web_ui.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.web_access]
}

# S3 Notifications to Trigger Lambda
resource "aws_lambda_permission" "allow_s3_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rekognition_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.image_inputs.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.image_inputs.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.rekognition_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.allow_s3_bucket]
}

# --- 4. COMPUTE (LAMBDA FUNCTION) ---
resource "aws_lambda_function" "rekognition_processor" {
  function_name = "group3_image_processor"
  role          = aws_iam_role.lambda_exec_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.rekognition_repo.repository_url}:latest"

  environment {
    variables = {
      OUTPUT_BUCKET = aws_s3_bucket.analysis_outputs.id
    }
  }

  timeout     = 60
  memory_size = 512
}

# --- 5. API GATEWAY SETUP ---
resource "aws_api_gateway_rest_api" "rekognition_api" {
  name        = "RekognitionAPI"
  description = "API for Group 3 Image Analysis"
}

resource "aws_api_gateway_resource" "analyze" {
  rest_api_id = aws_api_gateway_rest_api.rekognition_api.id
  parent_id   = aws_api_gateway_rest_api.rekognition_api.root_resource_id
  path_part   = "analyze"
}

# POST Method
resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.rekognition_api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rekognition_api.id
  resource_id             = aws_api_gateway_resource.analyze.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.rekognition_processor.invoke_arn
}

# OPTIONS Method (CORS)
resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.rekognition_api.id
  resource_id   = aws_api_gateway_resource.analyze.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.rekognition_api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id = aws_api_gateway_rest_api.rekognition_api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.rekognition_api.id
  resource_id = aws_api_gateway_resource.analyze.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Deployment and Permission
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rekognition_api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.analyze.id,
      aws_api_gateway_method.post_method.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_method.options_method.id,
      aws_api_gateway_integration.options_integration.id,
    ]))
  }
  lifecycle { create_before_destroy = true }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rekognition_api.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rekognition_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rekognition_api.execution_arn}/*/*"
}

# --- 6. OUTPUTS (UNIQUE) ---
output "website_url" {
  description = "The URL of the static website"
  value       = "http://${aws_s3_bucket_website_configuration.web_config.website_endpoint}"
}

output "api_endpoint" {
  description = "The API Gateway URL for script.js"
  value       = "${aws_api_gateway_stage.api_stage.invoke_url}/analyze"
}

output "website_bucket_name" {
  description = "The name of the S3 bucket for GitHub sync"
  value       = aws_s3_bucket.web_ui.id
}