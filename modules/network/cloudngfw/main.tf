# Public IP
resource "azurerm_public_ip" "this" {
  name                = var.public_ip_name
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Cloud NGFW - SCM Mode
resource "azurerm_palo_alto_next_generation_firewall_virtual_network_strata_cloud_manager" "this" {
  name                             = var.name
  resource_group_name              = var.resource_group_name
  location                         = var.location
  plan_id                          = var.plan_id
  marketplace_offer_id             = var.marketplace_offer_id
  strata_cloud_manager_tenant_name = var.strata_cloud_manager_tenant_name
  tags                             = var.tags

  network_profile {
    public_ip_address_ids = [azurerm_public_ip.this.id]

    vnet_configuration {
      virtual_network_id  = var.virtual_network_id
      trusted_subnet_id   = var.trusted_subnet_id
      untrusted_subnet_id = var.untrusted_subnet_id
    }
  }
}