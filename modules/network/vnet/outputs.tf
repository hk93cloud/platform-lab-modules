output "vnet" {
  description = <<-EOT
    Virtual network resource attributes.
    Contains: id, name, location, address_space
    Usage: module.vnet.vnet.id
  EOT
  value = {
    id           = azurerm_virtual_network.this.id
    name         = azurerm_virtual_network.this.name
    location     = azurerm_virtual_network.this.location
    address_space = azurerm_virtual_network.this.address_space
  }
}

output "subnets" {
  description = "Map of subnet names to subnet IDs."
  value = { for k, v in azurerm_subnet.this : k => v.id }
}

output "nsg" {
  description = <<-EOT
    Network Security Group resource attributes.
    Contains: id, name
    Usage: module.vnet.nsg.id
  EOT
  value = {
    id   = azurerm_network_security_group.this.id
    name = azurerm_network_security_group.this.name
  }
}
