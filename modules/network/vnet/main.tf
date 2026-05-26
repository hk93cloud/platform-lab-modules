resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  tags                = local.vnet_tags
}

resource "azurerm_network_security_group" "this" {
  name                = "${local.vnet_name}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.vnet_tags
}

resource "azurerm_subnet" "this" {
  for_each             = local.subnet_map
  name                 = each.key
  resource_group_name  = each.value.resource_group_name
  virtual_network_name = each.value.vnet_name
  address_prefixes     = [each.value.address_prefix]
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = azurerm_subnet.this
  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.this.id
}

resource "azurerm_network_security_rule" "this" {
  for_each = { for subnet_name, subnet in var.subnets :
    for rule in try(subnet.nsg_rules, []) :
      "${subnet_name}/${rule.name}" => merge(rule, { subnet_name = subnet_name })
  }
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = each.value.access
  protocol                    = each.value.protocol
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this.name
}
