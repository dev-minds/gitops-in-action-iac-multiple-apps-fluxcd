provider "aws" {
  #   version = "~> 2.57.0"
  region = "eu-west-1"
}

################################################################################
# Dynamic Id fetch 
################################################################################
locals {
  cluster_name = "gitops-in-action"
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "vpc-states"
    key    = "gitops-in-action-iac-multiple-apps-fluxcd/networking/terraform.tfstate"
    region = "eu-west-1"
  }
}

################################################################################
# Kubernetes provider configuration
################################################################################

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}



################################################################################
# EKS Module
################################################################################
module "eks" {
  source = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v12.1.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.20"

  vpc_id  = data.terraform_remote_state.networking.outputs.vpc_id
  subnets = data.terraform_remote_state.networking.outputs.public_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  node_groups = {
    ng-1 = {
      desired_capacity = 0
      max_capacity     = 3
      min_capacity     = 0

      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      k8s_labels = {
        Example    = "managed_node_groups"
        GithubRepo = "terraform-aws-eks"
        GithubOrg  = "terraform-aws-modules"
      }
      additional_tags = {
        ExtraTag = "example"
      }
      taints = [
        {
          key    = "dedicated"
          value  = "gpuGroup"
          effect = "NO_SCHEDULE"
        }
      ]
      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }
    }

    ng-2 = {
      desired_capacity = 2
      max_capacity     = 3
      min_capacity     = 1

      instance_types = ["t3.medium"]
      k8s_labels = {
        Example    = "managed_node_groups"
        GithubRepo = "terraform-aws-eks"
        GithubOrg  = "terraform-aws-modules"
      }
      additional_tags = {
        ExtraTag = "example2"
      }
      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }
    }
  }


  manage_aws_auth = false

  tags = {
    Environment = "main"
    Name        = local.cluster_name
    Managedby   = "Terraform"
  }
}

################################################################################
# Output: Cluster endpoint etc 
################################################################################
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "node_groups" {
  description = "Outputs from node groups"
  value       = module.eks.node_groups
}