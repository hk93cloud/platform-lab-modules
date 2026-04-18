output "id" {
  description = "Database ID"
  value       = azurerm_mssql_database.this.id
}

output "name" {
  description = "Database name"
  value       = azurerm_mssql_database.this.name
}