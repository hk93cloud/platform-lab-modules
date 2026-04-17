output "virtual_network_id" {
	description = "The ID of the virtual network."
	value       = azurerm_virtual_network.this.id
}

output "virtual_network_name" {
	description = "The name of the virtual network."
	value       = azurerm_virtual_network.this.name
}
