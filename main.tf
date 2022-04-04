terraform {
  required_version = ">= 0.13"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

resource "azurerm_resource_group" "rg-aulainfracould" {
  name     = "aulainfracloudterraform"
  location = "australiaeast"
}

resource "azurerm_virtual_network" "vnet-aula-infra-cloud" {
  name                = "vnet-auexercicio"
  location            = azurerm_resource_group.rg-aulainfracould.location
  resource_group_name = azurerm_resource_group.rg-aulainfracould.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "Production"
    tema = "exercicio"
    turma = "es22"
  }
}

resource "azurerm_subnet" "sub-exercicio-infra" {
  name                 = "sub-exercicio"
  resource_group_name  = azurerm_resource_group.rg-aulainfracould.name
  virtual_network_name = azurerm_virtual_network.vnet-aula-infra-cloud.name
  address_prefixes     = ["10.0.1.0/24"]
  
}
resource "azurerm_public_ip" "IP_Infra" {
  name                = "IP-Infra"
  resource_group_name = azurerm_resource_group.rg-aulainfracould.name
  location            = azurerm_resource_group.rg-aulainfracould.location
  allocation_method   = "Static"

  tags = {
    environment = "Production"
  }
}
resource "azurerm_network_security_group" "msg-infracloud" {
  name                = "msg-aulainfra"
  location            = azurerm_resource_group.rg-aulainfracould.location
  resource_group_name = azurerm_resource_group.rg-aulainfracould.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Production"
  }
} 
resource "azurerm_network_interface" "nic-ex-infra" {
  name                = "nic-ex-infra"
  location            = azurerm_resource_group.rg-aulainfracould.location
  resource_group_name = azurerm_resource_group.rg-aulainfracould.name

  ip_configuration {
    name                          = "ip-teste-nic"
    subnet_id                     = azurerm_subnet.sub-exercicio-infra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.IP_Infra.id
  }
}
resource "azurerm_network_interface_security_group_association" "nic-nsg-infra" {
  network_interface_id      = azurerm_network_interface.nic-ex-infra.id
  network_security_group_id = azurerm_network_security_group.msg-infracloud.id
}
resource "azurerm_virtual_machine" "vmaulainfra" {
  name                  = "vmaula"
  location              = azurerm_resource_group.rg-aulainfracould.location
  resource_group_name   = azurerm_resource_group.rg-aulainfracould.name
  network_interface_ids = [azurerm_network_interface.nic-ex-infra.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "hostname"
    admin_username = "testeadmin"
    admin_password = "Pasword0123456"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  
  tags = {
    environment = "staging"
  }
}

data "azurerm_public_ip" "IP-exe" {
  name = azurerm_public_ip.IP_Infra.name
  resource_group_name = azurerm_resource_group.rg-aulainfracould.name
}

resource "null_resource" "install-apache" {
  connection {
    type = "ssh"
    host = data.azurerm_public_ip.IP-exe.ip_address
    user = "testeadmin"
    password = "Pasword0123456"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  depends_on = [
    azurerm_virtual_machine.vmaulainfra
  ]
}
