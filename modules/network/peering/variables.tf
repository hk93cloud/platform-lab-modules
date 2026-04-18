variable "peering_name" {
	description = "The name of the peering."
	type        = string
}

variable "resource_group_name" {
	description = "The name of the resource group."
	type        = string
}

variable "virtual_network_name" {
	description = "The name of the local virtual network."
	type        = string
}

variable "remote_virtual_network_id" {
	description = "The ID of the remote virtual network."
	type        = string
}

variable "allow_virtual_network_access" {
	description = "Whether to allow VNet access."
	type        = bool
	default     = true
}

variable "allow_forwarded_traffic" {
	description = "Whether to allow forwarded traffic."
	type        = bool
	default     = false
}

variable "allow_gateway_transit" {
	description = "Whether to allow gateway transit."
	type        = bool
	default     = false
}

variable "use_remote_gateways" {
	description = "Whether to use remote gateways."
	type        = bool
	default     = false
}
