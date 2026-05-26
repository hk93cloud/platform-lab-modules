# ── Required Variables ──────────────────────────────────────────────────────

variable "name" {
  description = "Name of the Cloud NGFW resource."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy the Cloud NGFW into."
  type        = string
}

variable "location" {
  description = "Azure region where the Cloud NGFW will be deployed."
  type        = string
}

variable "plan_id" {
  description = "Marketplace billing plan ID."
  type        = string
}

variable "marketplace_offer_id" {
  description = "Marketplace offer ID."
  type        = string
}

variable "strata_cloud_manager_tenant_name" {
  description = <<-EOT
    Strata Cloud Manager tenant name that manages this firewall.
  EOT
  type      = string
  sensitive = true
}

variable "public_ip_name" {
  description = "Name of the public IP address to create and associate with the Cloud NGFW."
  type        = string
}

variable "virtual_network_id" {
  description = "ID of the VNet to attach the Cloud NGFW to."
  type        = string
}

variable "trusted_subnet_id" {
  description = "ID of the trusted (internal) subnet. Must have PaloAltoNetworks.Cloudngfw/firewalls delegation."
  type        = string
}

variable "untrusted_subnet_id" {
  description = "ID of the untrusted (external) subnet. Must have PaloAltoNetworks.Cloudngfw/firewalls delegation."
  type        = string
}

# ── Optional Variables ───────────────────────────────────────────────────────

variable "tags" {
  description = "Tags to apply to all resources in this module."
  type        = map(string)
  default     = {}
}