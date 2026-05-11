resource "azurerm_virtual_network" "agent" {
  count = var.enable_agent_vm ? 1 : 0

  name                = "vnet-agent-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "agent" {
  count = var.enable_agent_vm ? 1 : 0

  name                 = "snet-agent"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.agent[0].name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_public_ip" "agent" {
  count = var.enable_agent_vm ? 1 : 0

  name                = "pip-agent-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_security_group" "agent" {
  count = var.enable_agent_vm ? 1 : 0

  name                = "nsg-agent-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  security_rule {
    name                       = "allow-ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.agent_vm_allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "agent" {
  count = var.enable_agent_vm ? 1 : 0

  name                = "nic-agent-${local.base_name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.agent[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.agent[0].id
  }
}

resource "azurerm_network_interface_security_group_association" "agent" {
  count = var.enable_agent_vm ? 1 : 0

  network_interface_id      = azurerm_network_interface.agent[0].id
  network_security_group_id = azurerm_network_security_group.agent[0].id
}

resource "azurerm_linux_virtual_machine" "agent" {
  count = var.enable_agent_vm ? 1 : 0

  name                            = "vm-agent-${local.base_name}"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B1s"
  admin_username                  = var.agent_vm_admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.agent[0].id]
  tags                            = local.tags

  admin_ssh_key {
    username   = var.agent_vm_admin_username
    public_key = var.agent_vm_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
