variable "name" {
  description = "SQL Server name (must be globally unique)"
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

variable "administrator_login" {
  description = "SQL admin username"
  type        = string
}

variable "administrator_login_password" {
  description = "SQL admin password"
  type        = string
  sensitive   = true
}

variable "server_version" {
  description = "SQL Server version"
  type        = string
  default     = "12.0"
}

variable "public_network_access_enabled" {
  description = "Allow public network access"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}