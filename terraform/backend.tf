terraform {
  backend "s3" {
    bucket         = "nbs7-terraform-state-d4f58359"
    key            = "nbs7-test/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "nbs7-terraform-locks"
    encrypt        = true
  }
}
