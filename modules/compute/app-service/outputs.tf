output "id" {
  description = "App Service ID"
  value       = azurerm_linux_web_app.this.id
}

output "name" {
  description = "App Service name"
  value       = azurerm_linux_web_app.this.name
}

output "default_hostname" {
  description = "Default hostname of the app"
  value       = azurerm_linux_web_app.this.default_hostname
}

output "principal_id" {
  description = "Managed identity principal ID"
  value       = azurerm_linux_web_app.this.identity[0].principal_id
}