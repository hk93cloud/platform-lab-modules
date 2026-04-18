variable "name" {
  description = "Database name"
  type        = string
}

variable "server_id" {
  description = "SQL Server ID"
  type        = string
}

variable "sku_name" {
  description = "Database SKU (Basic, S0, S1, etc.)"
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}