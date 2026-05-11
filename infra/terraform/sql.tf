resource "random_password" "sql_admin" {
  count = var.enable_sql ? 1 : 0

  length           = 24
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

resource "azurerm_mssql_server" "main" {
  count = var.enable_sql ? 1 : 0

  name                         = "sql-${var.project_name}-${var.environment}-${local.suffix}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sql_admin[0].result
  minimum_tls_version          = "1.2"
  tags                         = local.tags
}

resource "azurerm_mssql_database" "main" {
  count = var.enable_sql ? 1 : 0

  name      = "${var.project_name}-${var.environment}"
  server_id = azurerm_mssql_server.main[0].id
  sku_name  = "Basic"
  collation = "SQL_Latin1_General_CP1_CI_AS"
  tags      = local.tags
}

resource "azurerm_key_vault_secret" "sql_admin_password" {
  count = var.enable_sql ? 1 : 0

  name         = "sql-admin-password"
  value        = random_password.sql_admin[0].result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_admin_current]
}
