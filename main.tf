# provider "aws" {
#   region                      = "us-east-1"
#   access_key                  = "admin12345localstack"
#   secret_key                  = "admin12345terraform"
#   skip_credentials_validation = true
#   skip_requesting_account_id  = true
#   skip_metadata_api_check     = true

#   endpoints {
#     rds         = "http://localhost:4566"
#   }
# }


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}


resource "aws_db_instance" "default" {
  allocated_storage    = 10
  engine               = "postgres"
  engine_version       = "13.4"
  instance_class       = "db.m6g.large"
  name                 = "mydb"
  username             = "dbuser"
  password             = "passwording"
  skip_final_snapshot  = true
}

###################################################
resource "aws_codecommit_repository" "hemantapp" {
  repository_name = "TheBestApp"
  description     = "This is seriously the best app"
}


###################################################
#Policy document specifying what service can assume the role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["amplify.amazonaws.com"]
    }
  }
}
#IAM role providing read-only access to CodeCommit
resource "aws_iam_role" "amplify-codecommit" {
  name                = "AmplifyCodeCommit"
  assume_role_policy  = join("", data.aws_iam_policy_document.assume_role.*.json)
  managed_policy_arns = ["arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"]
}


###################################################
resource "aws_amplify_app" "the-best-app" {
  name       = "The Best App"
  repository = aws_codecommit_repository.hemantapp.clone_url_http
  iam_service_role_arn = aws_iam_role.amplify-codecommit.arn
  enable_branch_auto_build = true
  build_spec = <<-EOT
    version: 0.1
    frontend:
      phases:
        preBuild:
          commands:
            - npm install
            - npm test -- --watchAll=false
        build:
          commands:
            - npm run build
      artifacts:
        baseDirectory: build
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
  EOT
  # The default rewrites and redirects added by the Amplify Console.
  custom_rule {
    source = "/<*>"
    status = "404"
    target = "/index.html"
  }
  environment_variables = {
    ENV = "dev"
  }
}

###################################################

resource "aws_amplify_branch" "develop" {
  app_id      = aws_amplify_app.the-best-app.id
  branch_name = "develop"
  framework = "React"
  stage     = "DEVELOPMENT"
}
resource "aws_amplify_branch" "master" {
  app_id      = aws_amplify_app.the-best-app.id
  branch_name = "master"
  framework = "React"
  stage     = "PRODUCTION"
}
