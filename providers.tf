terraform {
  required_version = ">= 1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # En non-prod : purge immédiate à la destruction pour ne pas bloquer
      # une recréation du même nom (soft-delete Key Vault).
      purge_soft_delete_on_destroy = true
    }
  }
}

# Le cluster est en Entra ID + Azure RBAC : kube_config ne fournit pas de
# credentials statiques utilisables (client_certificate et client_key sont
# vides). L'authentification passe donc par kubelogin, qui récupère un jeton
# depuis la session Azure CLI courante.
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.shared.kube_config[0].host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.shared.kube_config[0].cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "kubelogin"
    args = [
      "get-token",
      "--login", "azurecli",
      "--server-id", "6dae42f8-4368-4678-94ff-3960e28e3630"
    ]
  }
}