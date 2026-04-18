variable "name" {
  description = "Name of the App Service Plan"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group where the plan will be created"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "os_type" {
  description = "OS type for the plan (Linux or Windows)"
  type        = string
  default     = "Linux"
}

variable "sku_name" {
  description = "SKU name (B1, S1, P1v3, etc.)"
  type        = string
  default     = "B1"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}