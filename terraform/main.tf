terraform {
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.AWS_REGION
}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "eks-${random_string.suffix.result}"
  bucket_name = "kafka-connect-${lower(random_string.suffix.result)}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

resource "aws_s3_bucket" "kafka_bucket" {
  bucket = local.bucket_name
  force_destroy = true
}


resource "aws_iam_policy" "s3_access" {
  name        = "S3SparkAccessPolicy"
  description = "Allow Spark to access S3 bucket"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket"],
        Resource = "arn:aws:s3:::${local.bucket_name}"
      },
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Resource = "arn:aws:s3:::${local.bucket_name}/*"
      }
    ]
  })
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "kafka-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true

public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.13.1"

  cluster_name    = "kafka-eks-cluster-${lower(random_string.suffix.result)}"
  cluster_version = "1.32"

  subnet_ids = module.vpc.private_subnets
  vpc_id     = module.vpc.vpc_id
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    one = {
      name            = "node-group-1"
      instance_types  = ["t3.medium"]
      min_size        = 2
      max_size        = 5
      desired_size    = 3
    },
    two = {
      name            = "node-group-2"
      instance_types  = ["t3.medium"]
      min_size        = 1
      max_size        = 3
      desired_size    = 1
    }
  }
}


data "tls_certificate" "oidc_thumbprint" {
  url = module.eks.cluster_oidc_issuer_url
}



# Kafka S3 Source Connector config file
resource "local_file" "aws_connector_config" {
  filename = "aws-source-cc.json"
  content  = jsonencode({
    name   = "expedia",
    config = {
      "connector.class"         = "io.confluent.connect.s3.source.S3SourceConnector"
      "s3.bucket.name"          = aws_s3_bucket.kafka_bucket.bucket
      "s3.region"               = var.AWS_REGION
      "tasks.max"               = "3"
      "format.class"            = "io.confluent.connect.s3.format.avro.AvroFormat"
      "bootstrap.servers"       = "kafka:9071"
      "topics"                  = var.KAFKA_TOPICS
      "topics.dir"              = var.S3_TOPICS_DIR
      "aws.access.key.id"       = var.AWS_ACCESS_KEY_ID
      "aws.secret.access.key"   = var.AWS_SECRET_ACCESS_KEY
    }
  })

  depends_on = [aws_s3_bucket.kafka_bucket]

  lifecycle {
    replace_triggered_by = [aws_s3_bucket.kafka_bucket]
  }
}
