variable "cluster_name" {
  type    = string
  default = "homelab"
}

variable "k3d_servers" {
  type    = number
  default = 1
}

variable "k3d_agents" {
  type    = number
  default = 1
}

variable "kubeconfig_path" {
  type    = string
  default = "~/.kube/config"
}

variable "argocd_namespace" {
  type    = string
  default = "argocd"
}

variable "argocd_helm_version" {
  type    = string
  default = "9.1.3" #CHECK
}

variable "monitoring_app_path" {
  type        = string
  default     = "../../observability/app-of-apps/application.yaml"
  description = "Path to the monitoring ArgoCD root APP"
}

variable "apps_root_app_path" {
  type        = string
  default     = "../../argocd/app.yaml"
  description = "Path to the ArgoCD APP"
}
