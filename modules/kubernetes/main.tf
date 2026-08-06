# Ton namespace dédié dans le cluster mutualisé.
resource "kubernetes_namespace" "this" {
  metadata {
    name = var.namespace
    labels = {
      owner   = var.owner
      project = "tp-iac-azure-aks"
    }
  }
}

# --- NetworkPolicies -------------------------
# Le cluster est en networkPolicy=azure : ces règles filtrent réellement.

# 1) Deny-all par défaut : tout le trafic entrant du namespace est refusé,
#    on ouvre ensuite au cas par cas.
resource "kubernetes_network_policy" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
  }
}

# 2) L'ingress controller managé peut joindre le frontend.
resource "kubernetes_network_policy" "ingress_to_frontend" {
  metadata {
    name      = "allow-ingress-to-frontend"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "frontend" }
    }
    policy_types = ["Ingress"] # filtre l'entrée (Ingress) ou la sortie (Egress)
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "app-routing-system"
          }
        }
      }
      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }
  }
}

# 3) Seul le frontend peut joindre le backend (cœur de la contrainte).
resource "kubernetes_network_policy" "frontend_to_backend" {
  metadata {
    name      = "allow-frontend-to-backend"
    namespace = kubernetes_namespace.this.metadata[0].name
  }
  spec {
    pod_selector {
      match_labels = { app = "backend" }
    }
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {
          match_labels = { app = "frontend" }
        }
      }
      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }
  }
}

