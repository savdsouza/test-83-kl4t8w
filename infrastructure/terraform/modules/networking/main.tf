################################################################################
# Terraform configuration for the Dog Walking application's networking module.
# This file creates and manages:
#   - A highly available VPC with DNS features enabled
#   - Public subnets for load balancers
#   - Private subnets for services
#   - Flow logs for security monitoring
#   - Network ACLs with strict rules
#   - Optionally, NAT Gateway(s) and VPN Gateway for secure outbound access
#   - An S3 VPC endpoint for private service access
# The code below fulfills the technical specifications regarding:
#   1) Network Infrastructure (Section 2.5.1 Infrastructure Requirements)
#   2) High Availability (Section 8.1 Deployment Environment)
#   3) Security Architecture (Section 7.3.1 Access Control)
################################################################################

###############################################################################
# Specify required providers and versions.
###############################################################################
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # AWS provider ~> 5.0
    }
  }
}

###############################################################################
# Retrieve current AWS region, used for VPC endpoint configuration.
###############################################################################
data "aws_region" "current" {}

###############################################################################
# Main VPC resource with flow logs and enhanced security features.
#   - DNS Hostnames and DNS Support enabled
#   - Network address usage metrics enabled
#   - Tagged for environment-based organization
###############################################################################
resource "aws_vpc" "main" {
  cidr_block                           = var.vpc_cidr
  enable_dns_hostnames                 = true
  enable_dns_support                   = true
  instance_tenancy                     = "default"
  enable_network_address_usage_metrics = true

  tags = merge(
    {
      Name                  = "${var.environment}-vpc"
      Environment           = var.environment
      Project               = "dog-walking"
      SecurityLevel         = "high"
      CostCenter            = "networking"
    },
    var.tags
  )
}

###############################################################################
# Create a CloudWatch Log Group for VPC Flow Logs with log retention.
###############################################################################
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.environment}"
  retention_in_days = 30

  tags = merge(
    {
      Name        = "${var.environment}-flow-logs"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# VPC flow logs for security monitoring.
#   - Capture ALL traffic
#   - Logs directed to CloudWatch Log Group
###############################################################################
resource "aws_flow_log" "main" {
  vpc_id             = aws_vpc.main.id
  traffic_type       = "ALL"
  log_destination_type = "cloudwatch-logs"
  log_group_name       = aws_cloudwatch_log_group.flow_logs.name

  # NOTE: Usually you'd provide an IAM Role ARN here:
  # deliver_logs_permission_arn = ...
  # However, it is omitted if using default roles or if automatically provisioned.

  tags = merge(
    {
      Name        = "${var.environment}-flow-logs"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# Internet Gateway for public subnet traffic egress/ingress if needed.
###############################################################################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.environment}-igw"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# Public Subnets Definition
#   - Each subnet is mapped to a corresponding Availability Zone
#   - map_public_ip_on_launch = true for LB or outward-facing components
###############################################################################
resource "aws_subnet" "public" {
  for_each = {
    for idx, az in var.availability_zones :
    az => {
      cidr = var.public_subnet_cidrs[idx]
      index = idx
    }
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block             = each.value.cidr
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name        = "${var.environment}-public-subnet-${each.key}"
      Environment = var.environment
      Tier        = "public"
    },
    var.tags
  )
}

###############################################################################
# Public Route Table and association with each public subnet.
#   - Routes 0.0.0.0/0 to the Internet Gateway
###############################################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    {
      Name        = "${var.environment}-public-rt"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# EIP for NAT Gateway (only created if enable_nat_gateway is true).
###############################################################################
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  vpc = true

  depends_on = [aws_internet_gateway.main]

  tags = merge(
    {
      Name        = "${var.environment}-nat-eip"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# NAT Gateway for private subnets (optional).
#   - Provides secure outbound internet access for private subnets
###############################################################################
resource "aws_nat_gateway" "main" {
  count                  = var.enable_nat_gateway ? 1 : 0
  allocation_id          = element([for e in aws_eip.nat : e.id], 0)
  subnet_id              = length(aws_subnet.public) > 0 ? element([for s in aws_subnet.public : s.id], 0) : null
  connectivity_type      = "public"

  depends_on = [aws_eip.nat]

  tags = merge(
    {
      Name        = "${var.environment}-nat-gw"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# Private Subnets Definition
#   - Each subnet is mapped to a corresponding Availability Zone
#   - Used for backend services or data resources
###############################################################################
resource "aws_subnet" "private" {
  for_each = {
    for idx, az in var.availability_zones :
    az => {
      cidr = var.private_subnet_cidrs[idx]
      index = idx
    }
  }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.key

  tags = merge(
    {
      Name        = "${var.environment}-private-subnet-${each.key}"
      Environment = var.environment
      Tier        = "private"
    },
    var.tags
  )
}

###############################################################################
# Private Route Tables: one per Availability Zone to handle NAT or restricted route.
###############################################################################
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.main.id

  # Conditional route to NAT Gateway if enable_nat_gateway is true.
  # Otherwise, no default route is set for external access.
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = length(aws_nat_gateway.main) > 0 ? aws_nat_gateway.main[0].id : null
    }
  }

  tags = merge(
    {
      Name        = "${var.environment}-private-rt-${each.value.availability_zone}"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# Associate each private subnet with its corresponding private route table.
###############################################################################
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

###############################################################################
# Network ACLs for enhanced subnet security on private subnets.
#   - Example ingress rule: allow TCP traffic within the VPC CIDR range
#   - Egress rule default: allow all
###############################################################################
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [for s in aws_subnet.private : s.id]

  # Ingress rule for internal TCP traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.vpc_cidr
    from_port  = 0
    to_port    = 65535
  }

  # Egress rule for all traffic outbound
  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(
    {
      Name        = "${var.environment}-nacl-private"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# VPC Endpoint for secure AWS service access (S3 Gateway as an example).
#   - Attached to all private route tables for direct S3 access without NAT
###############################################################################
resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = merge(
    {
      Name        = "${var.environment}-s3-endpoint"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# Optional VPN Gateway for secure cross-region or site-to-site connectivity.
###############################################################################
resource "aws_vpn_gateway" "main" {
  count  = var.enable_vpn_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "${var.environment}-vgw"
      Environment = var.environment
    },
    var.tags
  )
}

###############################################################################
# OUTPUTS
# These exports provide critical information about the VPC, public and private
# subnets, and are used by other modules or external references.
###############################################################################

# Export VPC attributes, including an inline reference to the flow log resource.
output "vpc" {
  description = "Main VPC resource with flow log ID"
  value = {
    id          = aws_vpc.main.id
    cidr_block  = aws_vpc.main.cidr_block
    flow_log_id = aws_flow_log.main.id
  }
}

# Export Public Subnets details.
output "public_subnets" {
  description = "Public subnets with IDs, CIDRs, and AZs"
  value = [
    for s in aws_subnet.public :
    {
      id                = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  ]
}

# Export Private Subnets details.
output "private_subnets" {
  description = "Private subnets with IDs, CIDRs, and AZs"
  value = [
    for s in aws_subnet.private :
    {
      id                = s.id
      cidr_block        = s.cidr_block
      availability_zone = s.availability_zone
    }
  ]
}