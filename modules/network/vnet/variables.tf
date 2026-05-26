# ── Required Variables ──────────────────
variable "name" {
  type        = string
  description = "Name of the virtual network."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name for the VNet."
}

variable "location" {
  type        = string
  description = "Azure region for the VNet."
}

# ── Optional Variables ──────────────────
variable "address_space" {
  type        = list(string)
  description = "Address space for the VNet."
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  type = map(object({
    address_prefix    = string
    nsg_rules         = optional(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      source_port_range          = string
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = string
    })), [])
  }))
  description = "Map of subnet names to subnet configuration and optional NSG rules."
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources."
  default     = {}
}
