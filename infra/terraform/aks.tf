resource "azurerm_kubernetes_cluster" "main" {
  count = var.enable_aks ? 1 : 0

  name                = "aks-${local.base_name}-${local.suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "aks-${local.base_name}"
  sku_tier            = "Free"
  tags                = local.tags

  default_node_pool {
    name       = "system"
    vm_size    = "Standard_B2s"
    node_count = 1
    type       = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  network_profile {
    network_plugin = "kubenet"
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  count = var.enable_aks ? 1 : 0

  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main[0].kubelet_identity[0].object_id
}
