variable "name" {
  description = "Private endpoint name"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the private endpoint NIC will live"
  type        = string
}

variable "private_connection_resource_id" {
  description = "ID of the resource to connect to (e.g. SQL server ID)"
  type        = string
}

variable "subresource_names" {
  description = "Subresource names (e.g. [sqlServer], [blob], [vault])"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}