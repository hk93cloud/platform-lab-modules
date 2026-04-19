resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.virtual_network_name
  address_prefixes     = each.value.address_prefixes

  dynamic "delegation" {
    for_each = lookup(each.value, "delegation", null) != null ? [1] : []
    content {
      name = each.value.delegation.name
      service_delegation {
        name    = each.value.delegation.service_name
        actions = each.value.delegation.actions
      }
    }
  }
}