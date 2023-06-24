terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}


resource "digitalocean_kubernetes_cluster" "kubernetes_cluster" {
  name    = var.k8s_clustername
  region  = var.digitalocean_region
  version = var.k8s_version

  tags = ["k8s"]

  # This default node pool is mandatory
  node_pool {
    name       = var.k8s_poolname
    size       = "s-2vcpu-2gb"
    auto_scale = false
    node_count = var.k8s_count
    tags       = ["node-pool-tag"]
  }

}


provider "kubernetes" {
 // load_config_file = false
  host  = digitalocean_kubernetes_cluster.kubernetes_cluster.endpoint
  token = digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].cluster_ca_certificate
  )
}

provider "kubectl" {
  host                   = digitalocean_kubernetes_cluster.kubernetes_cluster.endpoint
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].cluster_ca_certificate)
  token                  = digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].token
  load_config_file       = false
}

provider "helm" {
  version = "~> 1.2"
  kubernetes {
    host  = digitalocean_kubernetes_cluster.kubernetes_cluster.endpoint
    token = digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].token
    cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.kubernetes_cluster.kube_config[0].cluster_ca_certificate)
  }
}


resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "ingress-nginx" {
  name  = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  namespace = "ingress-nginx"

  depends_on = [ kubernetes_namespace.ingress ]
}


//Ingress
resource "kubectl_manifest" "ingress-updater" {
  yaml_body = file("../k8s-cloud/ingress.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

//frontend
resource "kubectl_manifest" "frontend-service" {
  yaml_body = file("../k8s-cloud/frontend-service.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "frontend-deployment" {
  yaml_body = file("../k8s-cloud/frontend-deployment.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

//databse
resource "kubectl_manifest" "database-pvc" {
  yaml_body = file("../k8s-cloud/database-persistentvolumeclaim.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "database-service" {
  yaml_body = file("../k8s-cloud/database-service.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "database-deployment" {
  yaml_body = file("../k8s-cloud/database-deployment.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

//api
resource "kubectl_manifest" "configmap" {
  yaml_body = file("../k8s-cloud/opentourney-api-configmap.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "api_service" {
  yaml_body = file("../k8s-cloud/api-service.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "api-deployment" {
  yaml_body = file("../k8s-cloud/api-deployment.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "ws_service" {
  yaml_body = file("../k8s-cloud/ws-service.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "ws-deployment" {
  yaml_body = file("../k8s-cloud/ws-deployment.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}