resource "azurerm_linux_web_app" "this" {
  name                      = var.name
  resource_group_name       = var.resource_group_name
  location                  = var.location
  service_plan_id           = var.service_plan_id
  virtual_network_subnet_id = var.vnet_subnet_id

  # Disable basic auth publishing to avoid "listing Site Publishing Credential" errors
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    application_stack {
      java_version        = var.java_version
      java_server         = "JAVA"
      java_server_version = var.java_version
    }
  }

  app_settings = var.app_settings
  tags         = var.tags

  identity {
    type = "SystemAssigned"
  }
}