variable "name" {
  description = "Name of the App Service"
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

variable "service_plan_id" {
  description = "ID of the App Service Plan"
  type        = string
}

variable "java_version" {
  description = "Java version (e.g. 21, 17, 11)"
  type        = string
  default     = "21"
}

variable "vnet_subnet_id" {
  description = "Subnet ID for VNet integration (optional)"
  type        = string
  default     = null
}

variable "app_settings" {
  description = "App settings (env vars)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}