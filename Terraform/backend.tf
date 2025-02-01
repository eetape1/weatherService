terraform {
  backend "s3" {
    bucket         = ###redacted
    key            = "terraform/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
  }
}
