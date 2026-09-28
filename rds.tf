# =============================================================
# RDS PostgreSQL for Langfuse
#   - db.t3.medium in private subnets
#   - Accessible ONLY from EKS nodes (port 5432)
# =============================================================

# Subnet group - tells RDS which subnets to live in (private!)
resource "aws_db_subnet_group" "langfuse" {
  name       = "${var.cluster_name}-langfuse-db"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.cluster_name}-langfuse-db"
  }
}

# Security group - firewall for the RDS instance
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds-sg"
  description = "Allow PostgreSQL from EKS nodes only"
  vpc_id      = module.vpc.vpc_id

  # Allow inbound Postgres (5432) ONLY from EKS worker nodes
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-rds-sg"
  }
}

# The RDS PostgreSQL instance
resource "aws_db_instance" "langfuse" {
  identifier     = "${var.cluster_name}-langfuse"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.rds_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  db_name  = "langfuse"
  username = var.postgres_username
  password = var.postgres_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.langfuse.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Lab-friendly settings
  publicly_accessible     = false # private only - secure
  skip_final_snapshot     = true  # no snapshot on destroy (lab)
  deletion_protection     = false # allow easy teardown (lab)
  backup_retention_period = 1     # minimal backups for lab
  multi_az                = false # single AZ for lab (cheaper)

  tags = {
    Name = "${var.cluster_name}-langfuse-db"
  }
}

