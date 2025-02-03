provider "aws" {
  region = "us-east-2"
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

data "aws_vpc" "eks_vpc" {
  id = "vpc-0d9daef28aee01d6d"
}

resource "aws_eks_cluster" "weather_cluster" {
  name     = "WeatherCluster"
  role_arn = "arn:aws:iam::381492235736:role/AMZ_EKS_Cluster_Role"

  vpc_config {
    subnet_ids = [
      "subnet-0c5ca8131b25f1a9d",
      "subnet-03b3a7aa9da4b81f4"
    ]
  }

  tags = {
    Name = "WeatherCluster"
  }
}

data "aws_eks_cluster" "weather_cluster" {
  name       = aws_eks_cluster.weather_cluster.name
  depends_on = [aws_eks_cluster.weather_cluster]
}

data "aws_eks_cluster_auth" "weather_cluster" {
  name = aws_eks_cluster.weather_cluster.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.weather_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.weather_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.weather_cluster.token
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.weather_cluster.name
  addon_name   = "vpc-cni"
  
  configuration_values = jsonencode({
    env = {
      WARM_ENI_TARGET = "1"
      WARM_IP_TARGET  = "5"
    }
  })
  
  depends_on = [aws_eks_cluster.weather_cluster]
}

resource "aws_ec2_tag" "vpc_tag" {
  resource_id = data.aws_vpc.eks_vpc.id
  key         = "kubernetes.io/cluster/${aws_eks_cluster.weather_cluster.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "subnet_tags" {
  for_each    = toset(["subnet-0c5ca8131b25f1a9d", "subnet-03b3a7aa9da4b81f4"])
  resource_id = each.value
  key         = "kubernetes.io/cluster/${aws_eks_cluster.weather_cluster.name}"
  value       = "shared"
}

resource "aws_security_group" "worker_node_sg" {
  name        = "eks-worker-node-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = "vpc-0d9daef28aee01d6d"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.eks_vpc.cidr_block]
  }

  ingress {
    from_port   = 50051
    to_port     = 50051
    protocol    = "tcp"
    self        = true
    description = "Allow CNI port"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_eks_cluster.weather_cluster]
}

resource "aws_launch_template" "node_group_template" {
  name_prefix   = "eks-node-group"
  instance_type = "t3.medium"
  
  vpc_security_group_ids = [
    # aws_security_group.worker_node_sg.id,
    "sg-0dd9db7b318d71074"
  ]

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 20
      volume_type = "gp2"
    }
  }

  user_data = base64encode(<<-EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
/etc/eks/bootstrap.sh ${aws_eks_cluster.weather_cluster.name} \
  --container-runtime containerd \
  --kubelet-extra-args '--max-pods=110' \
  --b64-cluster-ca ${aws_eks_cluster.weather_cluster.certificate_authority[0].data}

--==MYBOUNDARY==--
EOF
  )

  depends_on = [aws_security_group.worker_node_sg]
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.weather_cluster.name
  node_group_name = "my-node-group-${random_string.node_group_suffix.result}"
  node_role_arn   = "arn:aws:iam::381492235736:role/Amazon-EKS-Node-Group-Role"
  subnet_ids      = ["subnet-0c5ca8131b25f1a9d", "subnet-03b3a7aa9da4b81f4"]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.node_group_template.id
    version = aws_launch_template.node_group_template.latest_version
  }

  tags = {
    "eks:nodegroup-name" = "my-node-group-${random_string.node_group_suffix.result}"
    "Name"               = "EKS-Node-Group"
    "kubernetes.io/cluster/${aws_eks_cluster.weather_cluster.name}" = "owned"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_launch_template.node_group_template]
}
