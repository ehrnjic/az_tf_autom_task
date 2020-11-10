# Use the Azure Resource Manager Provider
provider "azurerm" {
  version = "=2.35.0"
  features {}
}

# Create random string for password
resource "random_string" "rs" {
    length = 16
    special = true
    override_special = "/@£$"
}

# Create a new Resource Group
resource "azurerm_resource_group" "rg" {
  name = "rg-ehr-test"
  location = "North Europe"
}

# Create SQLServer
resource "azurerm_sql_server" "sql" {
  name = "sql-ehr-test-01"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  version = "12.0"
  administrator_login = "someadminuser"
  administrator_login_password = random_string.rs.result

  # This tag has no purpose in this env, it's only there just because you like tags :)
  tags = {
    env = "ehrtest"
  }  
}

# Create fw rule to allow access to db server (for any res in rg)
resource "azurerm_sql_firewall_rule" "fw" {
  name = "AllowAccessToDbServer"
  resource_group_name = azurerm_resource_group.rg.name
  server_name = azurerm_sql_server.sql.name
  start_ip_address = "0.0.0.0"
  end_ip_address = "0.0.0.0"

  depends_on = [azurerm_sql_server.sql]
}

# Create DB
resource "azurerm_sql_database" "db" {
  name = "db-ehr-test-01"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  server_name = azurerm_sql_server.sql.name
  requested_service_objective_name = "S0"

  depends_on = [azurerm_sql_server.sql]
}

# Create container registry
resource "azurerm_container_registry" "cr" {
  name = "crehrtest"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  admin_enabled = true
  sku = "Basic"
}

# Create an App Service Plan with Linux
resource "azurerm_app_service_plan" "asp" {
  name = "asp-ehr-test"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  kind = "Linux"
  reserved = true

  sku {
    tier = "Free"
    size = "F1"
  }
}

# Create an Azure Web App for Containers in that App Service Plan
resource "azurerm_app_service" "app" {
  name = "appehrtest"
  location = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = false
    DOCKER_REGISTRY_SERVER_URL = "https://${azurerm_container_registry.cr.name}.azurecr.io"
    DOCKER_REGISTRY_SERVER_USERMANE = azurerm_container_registry.cr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD = azurerm_container_registry.cr.admin_password
    DOCKER_ENABLE_CI = true
  }
  
  # Configure Docker Image to load on start
  site_config {
    use_32_bit_worker_process = "true"
    linux_fx_version = "DOCKER|${azurerm_container_registry.cr.login_server}/ehrnjicdotnetcoresqldbwebapp:latest"
  }

  connection_string {
      name = "MyDbConnection"
      type = "SQLServer"
      value = "Server=tcp:${azurerm_sql_server.sql.name}.database.windows.net,1433;Database=${azurerm_sql_database.db.name};User ID=someadminuser;Password=${random_string.rs.result};Encrypt=true;Connection Timeout=30;"
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_sql_database.db]
}