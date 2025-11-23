terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 3.75.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}

# Resource Group
resource "azurerm_resource_group" "devops_rg" {
  name     = "devops-learning-rg"
  location = "West US 2"
  
  tags = {
    Environment = "Learning"
    Project     = "DevOps-Training"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "devops_vnet" {
  name                = "devops-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name

  tags = {
    Environment = "Learning"
  }
}

# Subnet
resource "azurerm_subnet" "devops_subnet" {
  name                 = "devops-subnet"
  resource_group_name  = azurerm_resource_group.devops_rg.name
  virtual_network_name = azurerm_virtual_network.devops_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP for Jenkins (ONLY ONE PUBLIC IP)
resource "azurerm_public_ip" "jenkins_ip" {
  name                = "jenkins-public-ip"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Learning"
    Purpose     = "Jenkins-AllInOne"
  }
}

# Network Interface for Jenkins
resource "azurerm_network_interface" "jenkins_nic" {
  name                = "jenkins-nic"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.devops_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins_ip.id
  }

  tags = {
    Environment = "Learning"
  }
}

# Network Security Group for Jenkins
resource "azurerm_network_security_group" "jenkins_nsg" {
  name                = "jenkins-nsg"
  location            = azurerm_resource_group.devops_rg.location
  resource_group_name = azurerm_resource_group.devops_rg.name

  # SSH Access
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Jenkins Web UI
  security_rule {
    name                       = "Jenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Nexus Web UI
  security_rule {
    name                       = "Nexus"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8081"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Nexus Docker Registry
  security_rule {
    name                       = "NexusDocker"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8082"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Learning"
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "jenkins_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.jenkins_nic.id
  network_security_group_id = azurerm_network_security_group.jenkins_nsg.id
}

# Jenkins Virtual Machine (All-in-One)
resource "azurerm_linux_virtual_machine" "jenkins_vm" {
  name                = "jenkins-vm"
  resource_group_name = azurerm_resource_group.devops_rg.name
  location            = azurerm_resource_group.devops_rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "azureuser"
  
  network_interface_ids = [
    azurerm_network_interface.jenkins_nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("C:/Users/yashw/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  tags = {
    Environment = "Learning"
    Purpose     = "Jenkins-Nexus-XLDeploy"
  }
}

# Outputs
output "resource_group_name" {
  description = "Resource Group Name"
  value       = azurerm_resource_group.devops_rg.name
}

output "jenkins_public_ip" {
  description = "Jenkins VM Public IP"
  value       = azurerm_public_ip.jenkins_ip.ip_address
}

output "jenkins_ssh" {
  description = "SSH Command"
  value       = "ssh azureuser@${azurerm_public_ip.jenkins_ip.ip_address}"
}

output "jenkins_url" {
  description = "Jenkins Web UI"
  value       = "http://${azurerm_public_ip.jenkins_ip.ip_address}:8080"
}

output "nexus_url" {
  description = "Nexus Web UI (after installation)"
  value       = "http://${azurerm_public_ip.jenkins_ip.ip_address}:8081"
}

output "instructions" {
  description = "Next Steps"
  value       = <<-EOT
    
    ========================================
    Infrastructure Created Successfully!
    ========================================
    
    1. SSH to VM:
       ssh azureuser@${azurerm_public_ip.jenkins_ip.ip_address}
    
    2. Access Jenkins:
       http://${azurerm_public_ip.jenkins_ip.ip_address}:8080
    
    3. Access Nexus (after installing):
       http://${azurerm_public_ip.jenkins_ip.ip_address}:8081
    
    ========================================
  EOT
}