output "cloud_ngfw" {
  description = <<-EOT
    Cloud NGFW resource attributes.
    Contains: id, name
    Usage: module.azure_cloudngfw.cloud_ngfw.id
  EOT
  value = {
    id   = azurerm_palo_alto_next_generation_firewall_virtual_network_strata_cloud_manager.this.id
    name = azurerm_palo_alto_next_generation_firewall_virtual_network_strata_cloud_manager.this.name
  }
}

output "public_ip" {
  description = <<-EOT
    Public IP resource attributes.
    Contains: id, name, ip_address
    Usage: module.azure_cloudngfw.public_ip.ip_address
  EOT
  value = {
    id         = azurerm_public_ip.this.id
    name       = azurerm_public_ip.this.name
    ip_address = azurerm_public_ip.this.ip_address
  }
}