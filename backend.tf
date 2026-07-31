# Backend distant : le storage account et le container sont créés en amont
# par bootstrap.sh (œuf-poule : Terraform ne peut pas créer le backend qui
# héberge son propre state). Renseigner les valeurs affichées par le script,
# ou passer par -backend-config au `terraform init`.
terraform {
  backend "azurerm" {
    resource_group_name  = "msaidiRG"
    storage_account_name = "tfstatemohamedsaidi21794"
    container_name       = "tfstate"
    key                  = "nonprod.tfstate"
    use_azuread_auth     = true
  }
}
