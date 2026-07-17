# Bootstraps the S3 bucket + KMS key that hold Terraform state.
# Run this manually once per environment.
terraform {
  required_version = "~> 1.11"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83"
    }
  }
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "billing-chargebee-buyflow-tf-state-${var.environment}"
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "tf_state" {
  description = "KMS key for Terraform state ${var.environment}"
}

output "state_bucket" {
  value = aws_s3_bucket.tf_state.id
}

output "kms_key_arn" {
  value = aws_kms_key.tf_state.arn
}