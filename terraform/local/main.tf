terraform {
  required_version = ">= 1.6.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "null" {}
provider "local" {}

provider "kubernetes" {
  config_path = pathexpand(var.kubeconfig_path)
}

provider "helm" {
  kubernetes {
    config_path = pathexpand(var.kubeconfig_path)
  }
}

# -------------------------------------------------------------------
# 1) k3d cluster lifecycle
# -------------------------------------------------------------------
resource "null_resource" "k3d_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    servers      = tostring(var.k3d_servers)
    agents       = tostring(var.k3d_agents)
  }

  # CREATE CLUSTER
  provisioner "local-exec" {
    command = <<-EOF
      set -e
      echo "[TF] Creating k3d cluster ${var.cluster_name}..."
      k3d cluster create ${var.cluster_name} \
        --servers ${var.k3d_servers} \
        --agents ${var.k3d_agents} \
        -p "80:80@loadbalancer" \
        -p "443:443@loadbalancer" \
        --k3s-arg "--disable=traefik@server:0"

      echo "[TF] Merging kubeconfig..."
      k3d kubeconfig merge ${var.cluster_name} --kubeconfig-switch-context
    EOF
  }

  # DESTROY CLUSTER
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOF
      set -e
      echo "[TF] Deleting k3d cluster ${self.triggers.cluster_name}..."
      k3d cluster delete ${self.triggers.cluster_name} || true
    EOF
  }
}

# -------------------------------------------------------------------
# 2) Namespaces
# -------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
  depends_on = [null_resource.k3d_cluster]
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = "vault"
  }
  depends_on = [null_resource.k3d_cluster]
}

# -------------------------------------------------------------------
# 3) Vault via Helm
# -------------------------------------------------------------------
resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = "0.28.0" # adjust if you want

  namespace        = kubernetes_namespace.vault.metadata[0].name
  create_namespace = false

  values = [
    yamlencode({
      server = {
        dev = {
          enabled = false # real Vault, not dev mode
        }
        ha = {
          enabled = false
        }
        dataStorage = {
          enabled = true
        }
      }
      ui = {
        enabled = true
      }
    })
  ]

  depends_on = [
    null_resource.k3d_cluster
  ]
}

# -------------------------------------------------------------------
# 4) ArgoCD via Helm
# -------------------------------------------------------------------
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_helm_version

  namespace        = var.argocd_namespace
  create_namespace = false

  values = [
    yamlencode({
      server = {
        extraArgs = ["--insecure"]
      }
    })
  ]

  depends_on = [
    null_resource.k3d_cluster,
    kubernetes_namespace.argocd
  ]
}

# -------------------------------------------------------------------
# 5) Apply both ArgoCD roots (monitoring + app stack)
# -------------------------------------------------------------------
resource "null_resource" "monitoring_root_app" {
  provisioner "local-exec" {
    command = <<-EOF
      set -e
      echo "[TF] Applying monitoring root app..."
      kubectl apply -n ${var.argocd_namespace} -f ${var.monitoring_app_path}
    EOF
  }

  depends_on = [
    helm_release.argocd,
    helm_release.vault
  ]
}

resource "null_resource" "apps_root_app" {
  provisioner "local-exec" {
    command = <<-EOF
      set -e
      echo "[TF] Applying app stack root app..."
      kubectl apply -n ${var.argocd_namespace} -f ${var.apps_root_app_path}
    EOF
  }

  depends_on = [
    helm_release.argocd,
    helm_release.vault
  ]
}

