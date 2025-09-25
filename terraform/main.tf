terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Test VPC module (complete configuration)
module "test_vpc" {
  source = "./modules/vpc"

  resource_prefix = "nbs7-test"
  cidr            = "10.1.0.0/16"
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24"]
  public_subnets  = ["10.1.101.0/24", "10.1.102.0/24"]

  # Required variables that were missing
  create_igw             = true
  enable_nat_gateway     = true
  single_nat_gateway     = true  # Cost optimization
  one_nat_gateway_per_az = false # Cost optimization
  enable_dns_hostnames   = true
  enable_dns_support     = true
}

# Output VPC information
output "vpc_info" {
  value = {
    vpc_id          = module.test_vpc.vpc_id
    private_subnets = module.test_vpc.private_subnets
    public_subnets  = module.test_vpc.public_subnets
  }
}

# Shared MSK cluster for multi-tenant dev environments
module "shared_msk" {
  source = "./modules/shared-msk"

  resource_prefix   = "nbs7-test"
  create_shared_msk = true
  environment_type  = "development"

  vpc_id              = module.test_vpc.vpc_id
  msk_subnet_ids      = module.test_vpc.private_subnets
  allowed_cidr_blocks = [module.test_vpc.vpc_cidr_block]
  msk_ebs_volume_size = 50

  kafka_version = "3.6.0"

  additional_tags = {
    Environment = "test"
    CostCenter  = "NBS7"
  }
}

# Output MSK information
output "msk_info" {
  value = {
    cluster_arn       = module.shared_msk.cluster_arn
    bootstrap_brokers = module.shared_msk.bootstrap_brokers
  }
}

# Shared EKS cluster for multi-tenant dev environments  
module "shared_eks" {
  source = "./modules/eks-nbs"

  resource_prefix = "nbs7-test"
  name            = "nbs7-shared-dev-eks"
  vpc_id          = module.test_vpc.vpc_id
  subnets         = module.test_vpc.private_subnets

  # Cost-optimized sizing for testing
  instance_type       = "t3.medium"
  desired_nodes_count = 2
  max_nodes_count     = 3
  min_nodes_count     = 1
  ebs_volume_size     = 30

  cluster_version = "1.30"
  aws_role_arn    = var.eks_admin_role_arn
  sso_role_arn    = var.eks_admin_role_arn

  # Disable expensive features for testing
  deploy_argocd_helm         = "false"
  use_ecr_pull_through_cache = false

  allow_endpoint_public_access = true
  external_cidr_blocks         = ["0.0.0.0/0"] # For testing only
}

# Output EKS information

# Output EKS information
output "eks_info" {
  value = {
    cluster_name     = module.shared_eks.eks_cluster_name
    cluster_endpoint = module.shared_eks.eks_cluster_endpoint
  }
}

# Kubernetes provider configuration to connect to EKS cluster
provider "kubernetes" {
  host                   = module.shared_eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.shared_eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.shared_eks.eks_cluster_name]
  }
}
