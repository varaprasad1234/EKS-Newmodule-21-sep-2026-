module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Core add-ons
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  }

  # ▼▼▼ FIX: Allow pod-to-pod traffic across nodes ▼▼▼
  node_security_group_additional_rules = {
    # Node-to-node: allow ALL traffic between worker nodes (pod-to-pod)
    ingress_self_all = {
      description = "Node to node all ports/protocols (pod-to-pod)"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Control plane -> nodes: allow all (webhooks, metrics, etc.)
    ingress_cluster_all = {
      description                   = "Cluster/control-plane to node - all ports"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
  }
  # ▲▲▲ FIX ▲▲▲

  # EKS Managed Node Group -> Amazon Linux 2023
  eks_managed_node_groups = {
    al2023 = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        role = "worker"
      }
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = "prod"
    Platform    = "kong"
  }
}

