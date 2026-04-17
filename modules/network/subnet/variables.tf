variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "virtual_network_name" {
  description = "The name of the virtual network to associate with the subnet(s)."
  type        = string
}

variable "subnets" {
  description = "A map of objects describing subnets. The map key will be used as the subnet name. Each object must have 'address_prefixes'."
  type = map(object({
    address_prefixes = list(string)
  }))
}
