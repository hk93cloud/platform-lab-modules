output "id" {
  description = "SQL Server ID"
  value       = azurerm_mssql_server.this.id
}

output "name" {
  description = "SQL Server name"
  value       = azurerm_mssql_server.this.name
}

output "fully_qualified_domain_name" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}