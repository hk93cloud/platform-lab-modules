output "subnet_ids" {
  description = "The IDs of the created subnets."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}
