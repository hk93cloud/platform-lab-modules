locals {
  vnet_name = var.name
  vnet_tags = merge({ managed_by = "terraform" }, var.tags)

  subnet_map = {
    for k, v in var.subnets : k => merge(v, {
      resource_group_name = var.resource_group_name
      vnet_name           = var.name
    })
  }
}
