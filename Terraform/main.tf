provider "aws" {
  region = "us-east-2"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.existing_cluster.token
}

data "aws_eks_cluster" "existing_cluster" {
  name = "WeatherApp"
}

data "aws_eks_cluster_auth" "existing_cluster" {
  name = data.aws_eks_cluster.existing_cluster.name
}

resource "random_string" "node_group_suffix" {
  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = true
  keepers = {
      refresh_time = timestamp()
  }
}

resource "aws_eks_node_group" "eks_node_group" {
  
  cluster_name    = data.aws_eks_cluster.existing_cluster.name
  node_group_name = "my-node-group-${random_string.node_group_suffix.result}"
  node_role_arn   = "arn:aws:iam::381492235736:role/Amazon-EKS-Node-Group-Role"
  
  subnet_ids      = [
    "subnet-0c5ca8131b25f1a9d",
    "subnet-03b3a7aa9da4b81f4"
  ]

  # Private Subnets
  #   subnet_ids      = [
  #  "subnet-0fbd27d62123de106",
  #  "subnet-0d165e3cc8e537471"
  # ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  ami_type       = "AL2_x86_64"
  instance_types = ["t3.medium"]

  tags = {
    "eks:nodegroup-name" = "my-node-group-${random_string.node_group_suffix.result}"
    "Name"               = "EKS-Node-Group"
  }

  lifecycle {
    create_before_destroy = true
  }
}
