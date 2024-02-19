provider "aws" {
  region  = "us-west-2"
  profile = "nomimx"
}

terraform {
  backend "s3" {
    bucket  = "betty-bot"
    key     = "development/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
    profile = "nomimx"
  }
  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}


locals {
  region                 = "us-west-2"
  container_backend_name = "llm-service"
  container_backend_port = 8000
  ecr_address            = format("%v.dkr.ecr.%v.amazonaws.com", data.aws_caller_identity.this.account_id, data.aws_region.this.name)
}

data "aws_caller_identity" "this" {}
data "aws_ecr_authorization_token" "this" {}
data "aws_region" "this" {}

provider "docker" {
  host = "unix:///Users/206726210/.docker/run/docker.sock"
  registry_auth {
    address  = local.ecr_address
    password = data.aws_ecr_authorization_token.this.password
    username = data.aws_ecr_authorization_token.this.user_name
  }
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6.0"

  repository_force_delete = true
  repository_name         = "betty-bot"
  repository_lifecycle_policy = jsonencode({
    rules = [{
      action       = { type = "expire" }
      description  = "Delete all images except a handful of the newest images"
      rulePriority = 1
      selection = {
        countNumber = 3
        countType   = "imageCountMoreThan"
        tagStatus   = "any"
      }
    }]
  })
}

module "ecr_llm" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 1.6.0"

  repository_force_delete = true
  repository_name         = "betty-bot-llm-srv"
  repository_lifecycle_policy = jsonencode({
    rules = [{
      action       = { type = "expire" }
      description  = "Delete all images except a handful of the newest images"
      rulePriority = 1
      selection = {
        countNumber = 3
        countType   = "imageCountMoreThan"
        tagStatus   = "any"
      }
    }]
  })
}

resource "docker_image" "client" {
  name = format("%v:%v", module.ecr.repository_url, formatdate("YYYY-MM-DD'T'hh-mm-ss", timestamp()))
  build { context = "../../../Dockerfile" }
  platform = "linux/amd64"
}

# * Push our container image to our ECR.
resource "docker_registry_image" "client" {
  keep_remotely = true # Do not delete old images when a new image is pushed
  name          = resource.docker_image.client.name
}

resource "docker_image" "llm_service" {
  name = format("%v:%v", module.ecr_llm.repository_url, formatdate("YYYY-MM-DD'T'hh-mm-ss", timestamp()))
  build { context = "../../../llm-service" }
  platform = "linux/amd64"
}

# * Push our container image to our ECR.
resource "docker_registry_image" "llm_service" {
  keep_remotely = true # Do not delete old images when a new image is pushed
  name          = resource.docker_image.llm_service.name
}

data "aws_availability_zones" "available" { state = "available" }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.19.0"

  azs                = slice(data.aws_availability_zones.available.names, 0, 2) # Span subnetworks across 2 avalibility zones
  cidr               = "10.0.0.0/16"
  create_igw         = true # Expose public subnetworks to the Internet
  enable_nat_gateway = true # Hide private subnetworks behind NAT Gateway
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
  single_nat_gateway = true
  enable_dns_support = true
  enable_dns_hostnames = true
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.4.0"

  load_balancer_type = "application"
  security_groups    = [module.vpc.default_security_group_id]
  subnets            = module.vpc.public_subnets
  vpc_id             = module.vpc.vpc_id

  security_group_rules = {
    ingress_all_http = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      description = "Permit incoming HTTP requests from the internet"
      cidr_blocks = ["0.0.0.0/0"]
    }
    egress_all = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "Permit all outgoing requests to the internet"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  http_tcp_listeners = [
    {
      # * Setup a listener on port 80 and forward all HTTP
      # * traffic to target_groups[0] defined below which
      # * will eventually point to our "Hello World" app.
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      backend_port     = local.container_client_port
      backend_protocol = "HTTP"
      target_type      = "ip"
    }
  ]
}

module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 4.1.3"

  cluster_name = "betty-bot-dev"

  # * Allocate 20% capacity to FARGATE and then split
  # * the remaining 80% capacity 50/50 between FARGATE
  # * and FARGATE_SPOT.
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        base   = 20
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }
}

data "aws_iam_role" "ecs_task_execution_role" { name = "ecsTaskExecutionRole" }

resource "aws_ecs_task_definition" "client" {
  container_definitions = jsonencode([{
    environment : [
      { name = "LLM_API_HOST", value = "http://llm-service.payrollguru.com:8080" }
    ],
    logConfiguration= {
      logDriver= "awslogs",
      options= {
          awslogs-create-group= "true",
          awslogs-group= "client-logs",
          awslogs-region= "us-west-2",
          awslogs-stream-prefix= "awslogs-client"
      }
    },
    essential    = true,
    # image        = resource.docker_image.client.name,
    image        = "benzzdan/client-payrollguru",
    name         = "client",
    portMappings = [{ containerPort = local.container_client_port }],
  }])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "X86_64"
  }

  cpu                      = 256
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  task_role_arn = "arn:aws:iam::324522967809:role/nomi-ecs-fargate-dev-v9-NomiexecutivebackenddevTas-1NR2XXD30KL49" # change this
  family                   = "family-of-payrollguru-tasks"
  memory                   = 2048
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_task_definition" "llm_service" {
  container_definitions = jsonencode([{
    environment : [
      { name = "NODE_ENV", value = "production" },
      { name = "DBNOMI_USER_NAME", value = "postgres_ro" },
      { name = "DBNOMI_PASSWORD", value = "N0m1dev$3r23" },
      { name = "DBNOMI_HOST", value = "ecs-fargate-dev.cess1llr3ch0.us-east-2.rds.amazonaws.com" },
      { name = "DBNOMI_DB_NAME", value = "integrity" },
      { name = "AWS_SECRET_ACCESS_KEY", value = "cmxwI5DisjD18EJ6jrqtNW5f+Dj5dP+Qgpu4jOWN" },
      { name = "AWS_ACCESS_KEY_ID", value = "AKIAUXDYTQMA24EVBYUX" },
      { name = "AWS_DEFAULT_REGION", value = "us-west-2" },
      { name = "LLM_MODEL_ID", value = "anthropic.claude-v2" },
    ],
    logConfiguration= {
      logDriver= "awslogs",
      options= {
          awslogs-create-group= "true",
          awslogs-group= "client-logs",
          awslogs-region= "us-west-2",
          awslogs-stream-prefix= "awslogs-client"
      }
    },
    essential    = true,
    # image        = resource.docker_image.client.name,
    image        = "benzzdan/llm-payrollguru"
    name         = "llm-service",
    portMappings = [{ containerPort = local.container_client_port }],
  }])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture = "X86_64"
  }

  cpu                      = 256
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  family                   = "family-of-payrollguru-tasks"
  memory                   = 2048
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

resource "aws_ecs_service" "client" {
  cluster         = module.ecs.cluster_id
  desired_count   = 1
  launch_type     = "FARGATE"
  name            = "client-service"
  task_definition = resource.aws_ecs_task_definition.client.arn

  lifecycle {
    ignore_changes = [desired_count] # Allow external changes to happen without Terraform conflicts, particularly around auto-scaling.
  }

  load_balancer {
    container_name   = "client"
    container_port   = local.container_client_port
    target_group_arn = module.alb.target_group_arns[0]
  }

  network_configuration {
    security_groups = [module.vpc.default_security_group_id]
    subnets         = module.vpc.private_subnets
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.client_service.arn}"
  }
}

resource "aws_ecs_service" "llm_service" {
  cluster         = module.ecs.cluster_id
  desired_count   = 1
  launch_type     = "FARGATE"
  name            = "llm-service"
  task_definition = resource.aws_ecs_task_definition.llm_service.arn

  lifecycle {
    ignore_changes = [desired_count] # Allow external changes to happen without Terraform conflicts, particularly around auto-scaling.
  }

  network_configuration {
    security_groups = [module.vpc.default_security_group_id]
    subnets         = module.vpc.private_subnets
  }

  service_registries {
    registry_arn = "${aws_service_discovery_service.llm_service.arn}"
  }
}
