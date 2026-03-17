# Terraform configuration for multi-region Keycloak deployment
# Supports AWS, Azure, GCP

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "keycloak-terraform-state"
    key    = "multi-region/terraform.tfstate"
    region = "us-east-1"
  }
}

# Variables
variable "regions" {
  description = "List of AWS regions for deployment"
  type        = list(string)
  default     = ["us-east-1", "eu-west-1", "ap-southeast-1"]
}

variable "keycloak_version" {
  description = "Keycloak version"
  type        = string
  default     = "24.0"
}

variable "instance_type" {
  description = "EC2 instance type for Keycloak"
  type        = string
  default     = "m5.2xlarge"
}

variable "database_instance_type" {
  description = "RDS instance type"
  type        = string
  default     = "db.r5.2xlarge"
}

# Provider configuration for each region
provider "aws" {
  alias  = "us_east"
  region = var.regions[0]
}

provider "aws" {
  alias  = "eu_west"
  region = var.regions[1]
}

provider "aws" {
  alias  = "ap_southeast"
  region = var.regions[2]
}

# VPC for each region
module "vpc_us_east" {
  source = "./modules/vpc"
  providers = {
    aws = aws.us_east
  }

  region        = var.regions[0]
  cidr_block    = "10.0.0.0/16"
  region_suffix = "use1"
}

module "vpc_eu_west" {
  source = "./modules/vpc"
  providers = {
    aws = aws.eu_west
  }

  region        = var.regions[1]
  cidr_block    = "10.1.0.0/16"
  region_suffix = "euw1"
}

module "vpc_ap_southeast" {
  source = "./modules/vpc"
  providers = {
    aws = aws.ap_southeast
  }

  region        = var.regions[2]
  cidr_block    = "10.2.0.0/16"
  region_suffix = "apse1"
}

# RDS Primary (us-east-1)
resource "aws_db_instance" "postgres_primary" {
  provider = aws.us_east

  identifier           = "keycloak-db-primary"
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = var.database_instance_type
  allocated_storage     = 1000
  storage_type         = "gp3"
  storage_encrypted     = true

  db_name  = "keycloak"
  username = "keycloak"
  password = var.db_password

  vpc_security_group_ids = [module.vpc_us_east.db_security_group_id]
  db_subnet_group_name   = module.vpc_us_east.db_subnet_group_name

  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "keycloak-db-primary-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name        = "keycloak-db-primary"
    Environment = "production"
    Region      = var.regions[0]
  }
}

# RDS Read Replicas in other regions
resource "aws_db_instance" "postgres_replica_eu" {
  provider = aws.eu_west

  identifier             = "keycloak-db-replica-eu"
  replicate_source_db    = aws_db_instance.postgres_primary.arn
  instance_class         = var.database_instance_type
  publicly_accessible    = false
  skip_final_snapshot    = true

  vpc_security_group_ids = [module.vpc_eu_west.db_security_group_id]
  db_subnet_group_name   = module.vpc_eu_west.db_subnet_group_name

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = "keycloak-db-replica-eu"
    Environment = "production"
    Region      = var.regions[1]
  }
}

resource "aws_db_instance" "postgres_replica_ap" {
  provider = aws.ap_southeast

  identifier             = "keycloak-db-replica-ap"
  replicate_source_db    = aws_db_instance.postgres_primary.arn
  instance_class         = var.database_instance_type
  publicly_accessible    = false
  skip_final_snapshot    = true

  vpc_security_group_ids = [module.vpc_ap_southeast.db_security_group_id]
  db_subnet_group_name   = module.vpc_ap_southeast.db_subnet_group_name

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name        = "keycloak-db-replica-ap"
    Environment = "production"
    Region      = var.regions[2]
  }
}

# ECS/EKS clusters for Keycloak in each region
module "keycloak_cluster_us_east" {
  source = "./modules/keycloak-cluster"
  providers = {
    aws = aws.us_east
  }

  region              = var.regions[0]
  vpc_id              = module.vpc_us_east.vpc_id
  subnet_ids          = module.vpc_us_east.private_subnet_ids
  db_endpoint         = aws_db_instance.postgres_primary.endpoint
  db_replica_endpoint = aws_db_instance.postgres_primary.endpoint
  keycloak_version    = var.keycloak_version
  instance_count      = 3
}

module "keycloak_cluster_eu_west" {
  source = "./modules/keycloak-cluster"
  providers = {
    aws = aws.eu_west
  }

  region              = var.regions[1]
  vpc_id              = module.vpc_eu_west.vpc_id
  subnet_ids          = module.vpc_eu_west.private_subnet_ids
  db_endpoint         = aws_db_instance.postgres_replica_eu.endpoint
  db_replica_endpoint = aws_db_instance.postgres_replica_eu.endpoint
  keycloak_version    = var.keycloak_version
  instance_count      = 3
}

module "keycloak_cluster_ap_southeast" {
  source = "./modules/keycloak-cluster"
  providers = {
    aws = aws.ap_southeast
  }

  region              = var.regions[2]
  vpc_id              = module.vpc_ap_southeast.vpc_id
  subnet_ids          = module.vpc_ap_southeast.private_subnet_ids
  db_endpoint         = aws_db_instance.postgres_replica_ap.endpoint
  db_replica_endpoint = aws_db_instance.postgres_replica_ap.endpoint
  keycloak_version    = var.keycloak_version
  instance_count      = 3
}

# Application Load Balancers for each region
resource "aws_lb" "keycloak_us_east" {
  provider = aws.us_east

  name               = "keycloak-alb-use1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.vpc_us_east.alb_security_group_id]
  subnets            = module.vpc_us_east.public_subnet_ids

  enable_deletion_protection = true
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "keycloak-alb-use1"
    Region = var.regions[0]
  }
}

resource "aws_lb" "keycloak_eu_west" {
  provider = aws.eu_west

  name               = "keycloak-alb-euw1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.vpc_eu_west.alb_security_group_id]
  subnets            = module.vpc_eu_west.public_subnet_ids

  enable_deletion_protection = true
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "keycloak-alb-euw1"
    Region = var.regions[1]
  }
}

resource "aws_lb" "keycloak_ap_southeast" {
  provider = aws.ap_southeast

  name               = "keycloak-alb-apse1"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.vpc_ap_southeast.alb_security_group_id]
  subnets            = module.vpc_ap_southeast.public_subnet_ids

  enable_deletion_protection = true
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "keycloak-alb-apse1"
    Region = var.regions[2]
  }
}

# Outputs
output "alb_dns_us_east" {
  value       = aws_lb.keycloak_us_east.dns_name
  description = "DNS name of US East ALB"
}

output "alb_dns_eu_west" {
  value       = aws_lb.keycloak_eu_west.dns_name
  description = "DNS name of EU West ALB"
}

output "alb_dns_ap_southeast" {
  value       = aws_lb.keycloak_ap_southeast.dns_name
  description = "DNS name of AP Southeast ALB"
}

output "db_primary_endpoint" {
  value       = aws_db_instance.postgres_primary.endpoint
  description = "Primary database endpoint"
  sensitive   = true
}
