###################################################################################################
# Terraform Variables for Security Module
# -----------------------------------------------------------------------------------------------
# This file defines all input variables for the security module, which manages:
# - Web Application Firewall (WAF) configurations
# - Security Groups (SGs)
# - IAM roles and access controls
# - KMS-based encryption and key rotation
#
# In direct alignment with:
# • Security Architecture (Tech Specs §2.4.2) to configure WAF and network security.
# • Data Security (Tech Specs §7.2) for encryption standards and protection measures.
# • Access Control (Tech Specs §7.3.1) to uphold authentication, authorization, and rate limiting.
#
# External Provider Reference:
#   - hashicorp/aws ~> 5.0
###################################################################################################

/***************************************************************************************************
 * Variable: name
 * Description:
 *   Name prefix for security resources. Ensures consistent naming following predefined patterns
 *   from the Security Architecture (Tech Specs §2.4.2) for easier identification and management.
 * Validation:
 *   Only lowercase letters, numbers, and hyphens, aligning with standardized naming rules.
 **************************************************************************************************/
variable "name" {
  type        = string
  description = "Name prefix for security resources."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name))
    error_message = "Name must contain only lowercase letters, numbers, and hyphens."
  }
}

/***************************************************************************************************
 * Variable: env
 * Description:
 *   Environment identifier (dev, staging, or prod). Used for tagging and resource grouping,
 *   reflecting the environment separation outlined in Access Control (Tech Specs §7.3.1),
 *   ensuring each environment’s security posture can be individually managed.
 * Validation:
 *   Must be one of dev, staging, or prod.
 **************************************************************************************************/
variable "env" {
  type        = string
  description = "Environment identifier for resource naming and tagging."

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.env))
    error_message = "Environment must be dev, staging, or prod."
  }
}

/***************************************************************************************************
 * Variable: vpc_id
 * Description:
 *   ID of the VPC in which security resources (e.g., security groups) will be created. This
 *   variable is pivotal for correct network segmentation and secure resource placement per
 *   Security Architecture (Tech Specs §2.4.2).
 **************************************************************************************************/
variable "vpc_id" {
  type        = string
  description = "ID of the VPC where security groups will be created."
}

/***************************************************************************************************
 * Variable: waf_rate_limit
 * Description:
 *   The maximum number of requests allowed per five-minute interval per IP address, aligning with
 *   Access Control (Tech Specs §7.3.1) to mitigate DDoS or brute-force attacks via rate limiting.
 * Default: 2000
 *   This default suits modest traffic while preventing excessive requests from a single source.
 * Validation:
 *   Must be between 100 and 10000 requests per 5 minutes.
 **************************************************************************************************/
variable "waf_rate_limit" {
  type        = number
  description = "Maximum number of requests per 5 minutes per IP for WAF rate-based rules."
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 10000
    error_message = "WAF rate limit must be between 100 and 10000 requests per 5 minutes."
  }
}

/***************************************************************************************************
 * Variable: allowed_ip_ranges
 * Description:
 *   A list of IP CIDR ranges permitted through the WAF, enforcing IP filtering controls described
 *   in Access Control (Tech Specs §7.3.1). This can be used to whitelist specific offices or networks.
 * Default: []
 * Validation:
 *   Each entry must be a valid CIDR notation (e.g., 192.168.0.0/24).
 **************************************************************************************************/
variable "allowed_ip_ranges" {
  type        = list(string)
  description = "List of allowed IP CIDR ranges for WAF IP filtering."
  default     = []

  validation {
    condition     = alltrue([for ip in var.allowed_ip_ranges : can(cidrhost(ip, 0))])
    error_message = "All IP ranges must be valid CIDR notation."
  }
}

/***************************************************************************************************
 * Variable: service_ports
 * Description:
 *   Defines port and protocol mappings for each core service, ensuring the environment’s
 *   Security Groups are accurately configured. Aligns with Security Architecture (Tech Specs §2.4.2)
 *   for controlled access to microservices.
 * Default:
 *   {
 *     api_gateway        = { port = 443,  protocol = "tcp" }
 *     auth_service       = { port = 8080, protocol = "tcp" }
 *     booking_service    = { port = 8081, protocol = "tcp" }
 *     tracking_service   = { port = 8082, protocol = "tcp" }
 *     payment_service    = { port = 8083, protocol = "tcp" }
 *     notification_service = { port = 8084, protocol = "tcp" }
 *   }
 * Validation:
 *   Port must be 1-65535 and protocol must be either "tcp" or "udp".
 **************************************************************************************************/
variable "service_ports" {
  type = map(object({
    port     = number
    protocol = string
  }))

  description = "Map of service names to their port and protocol configurations."

  default = {
    api_gateway = {
      port     = 443
      protocol = "tcp"
    }
    auth_service = {
      port     = 8080
      protocol = "tcp"
    }
    booking_service = {
      port     = 8081
      protocol = "tcp"
    }
    tracking_service = {
      port     = 8082
      protocol = "tcp"
    }
    payment_service = {
      port     = 8083
      protocol = "tcp"
    }
    notification_service = {
      port     = 8084
      protocol = "tcp"
    }
  }

  validation {
    condition = alltrue([
      for k, v in var.service_ports :
      v.port >= 1 && v.port <= 65535 && contains(["tcp", "udp"], v.protocol)
    ])
    error_message = "Port must be between 1-65535 and protocol must be tcp or udp."
  }
}

/***************************************************************************************************
 * Variable: enable_key_rotation
 * Description:
 *   Boolean flag enabling/disabling automatic KMS key rotation, meeting Data Security (Tech Specs §7.2)
 *   to reduce exposure via periodic cryptographic key changes.
 * Default: true
 **************************************************************************************************/
variable "enable_key_rotation" {
  type        = bool
  description = "Enable automatic KMS key rotation."
  default     = true
}

/***************************************************************************************************
 * Variable: kms_deletion_window
 * Description:
 *   Waiting period before a KMS key is permanently deleted, fulfilling Data Security (Tech Specs §7.2)
 *   requirements for secure key retirement and potential key recovery.
 * Default: 30
 * Validation:
 *   Must be between 7 and 30 days inclusive.
 **************************************************************************************************/
variable "kms_deletion_window" {
  type        = number
  description = "Waiting period before KMS key deletion (7-30 days)."
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS key deletion window must be between 7 and 30 days."
  }
}

/***************************************************************************************************
 * Variable: enable_waf
 * Description:
 *   Boolean controlling whether WAF is deployed for the API Gateway. Aligns with Security Architecture
 *   (Tech Specs §2.4.2) and Access Control measures (Tech Specs §7.3.1).
 * Default: true
 **************************************************************************************************/
variable "enable_waf" {
  type        = bool
  description = "Enable WAF protection for API Gateway."
  default     = true
}

/***************************************************************************************************
 * Variable: waf_block_rules
 * Description:
 *   A list of WAF rule objects specifying how to handle malicious requests. This directly implements
 *   Data Security (Tech Specs §7.2) and Access Control (Tech Specs §7.3.1) by blocking or counting
 *   known threat patterns.
 * Default:
 *   [
 *     { name = "SQLInjection",   priority = 1, action = "block" },
 *     { name = "XSSAttack",      priority = 2, action = "block" },
 *     { name = "PathTraversal",  priority = 3, action = "block" }
 *   ]
 * Validation:
 *   - The "action" must be one of ["allow", "block", "count"].
 *   - The "priority" should be a positive integer indicating the rule order.
 **************************************************************************************************/
variable "waf_block_rules" {
  type = list(object({
    name     = string
    priority = number
    action   = string
  }))

  description = "List of WAF rule configurations for blocking malicious requests."

  default = [
    {
      name     = "SQLInjection"
      priority = 1
      action   = "block"
    },
    {
      name     = "XSSAttack"
      priority = 2
      action   = "block"
    },
    {
      name     = "PathTraversal"
      priority = 3
      action   = "block"
    },
  ]

  validation {
    condition = alltrue([
      for rule in var.waf_block_rules :
      contains(["allow", "block", "count"], rule.action) && rule.priority > 0
    ])
    error_message = "WAF rule action must be allow, block, or count and priority must be positive."
  }
}

/***************************************************************************************************
 * Variable: tags
 * Description:
 *   A map of key-value pairs to apply as standard tags on all security-related resources. Helps with
 *   resource traceability and cost allocation across multiple environments and services per
 *   Security Architecture (Tech Specs §2.4.2).
 * Default: {}
 **************************************************************************************************/
variable "tags" {
  type        = map(string)
  description = "Additional tags for security resources."
  default     = {}
}