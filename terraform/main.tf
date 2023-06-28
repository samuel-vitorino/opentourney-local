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
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "4.4.0"
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


data "kubernetes_ingress_v1" "example" {
  metadata {
    name = "opentourney-ingress"
  }
  depends_on = [
    data.kubernetes_ingress_v1.example,
    helm_release.ingress-nginx,
    kubernetes_namespace.ingress,
    data.kubernetes_ingress_v1.example,
    helm_release.ingress-nginx,
    kubernetes_namespace.ingress,
    kubectl_manifest.ingress-updater,
    kubectl_manifest.frontend-service,
    kubectl_manifest.frontend-deployment,
    kubectl_manifest.database-pvc,
    kubectl_manifest.database-service,
    kubectl_manifest.database-deployment,
    kubectl_manifest.configmap,
    kubectl_manifest.api_service,
    kubectl_manifest.api-deployment,
    kubectl_manifest.ws_service,
    kubectl_manifest.ws-deployment
  ]
}

output "ip" {
  value = data.kubernetes_ingress_v1.example.status.0.load_balancer.0.ingress.0.ip
  depends_on = [ data.kubernetes_ingress_v1.example ]
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

resource "kubectl_manifest" "api_cluster_permissions" {
  yaml_body = file("../k8s-cloud/cluster-auth/cluster-auth.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "api_volume" {
  yaml_body = file("../k8s-cloud/api-volume.yaml")
  depends_on = [ helm_release.ingress-nginx, kubectl_manifest.api_cluster_permissions ]
}

resource "kubectl_manifest" "configmap" {
  yaml_body = file("../k8s-cloud/opentourney-api-configmap.yaml")
  depends_on = [ helm_release.ingress-nginx, kubectl_manifest.api_volume ]
}

resource "kubectl_manifest" "api_service" {
  yaml_body = file("../k8s-cloud/api-service.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "api-deployment" {
  yaml_body = file("../k8s-cloud/api-deployment.yaml")
  depends_on = [ helm_release.ingress-nginx, kubectl_manifest.configmap ]
}

//ws
resource "kubectl_manifest" "ws_service" {
  yaml_body = file("../k8s-cloud/ws-service.yaml")
  depends_on = [ helm_release.ingress-nginx ]
}

resource "kubectl_manifest" "ws-deployment" {
  yaml_body = file("../k8s-cloud/ws-deployment.yaml")
  depends_on = [ helm_release.ingress-nginx, kubectl_manifest.configmap ]
}

//CLOUDFLARE
resource "cloudflare_record" "example" {
  zone_id = "50657706a4f9844b2052af3293dbd0f7"
  name    = "@"
  type    = "A"
  value   =  data.kubernetes_ingress_v1.example.status.0.load_balancer.0.ingress.0.ip
  ttl     = 3600

  depends_on = [ data.kubernetes_ingress_v1.example ]
}

resource "kubernetes_namespace" "create_cert_manager_namespace" {
  metadata {
    name = "cert-manager"
  }
  depends_on = [ cloudflare_record.example ]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  create_namespace = false
  version    = "v1.12.0"
  namespace  = "cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [ kubernetes_namespace.create_cert_manager_namespace ]
}

resource "kubectl_manifest" "cert_manager_cert_issuer" {
  yaml_body = file("../k8s-cloud/cert-manager/cert-issuer-nginx-ingress.yaml")
  depends_on = [ helm_release.cert_manager ]
}

resource "kubectl_manifest" "cert_manager_save_cert" {
  yaml_body = file("../k8s-cloud/cert-manager/certificate.yaml")
  depends_on = [ kubectl_manifest.cert_manager_cert_issuer ]
}

resource "kubectl_manifest" "apply_new_tls_ingress" {
  yaml_body = file("../k8s-cloud/cert-manager/ingress_working_for_domain.yaml")
  depends_on = [ kubectl_manifest.cert_manager_save_cert ]
}

//CS
resource "kubectl_manifest" "cs_volume" {
  yaml_body = file("../k8s-cloud/cs/cs-volume.yaml")
  depends_on = [ digitalocean_kubernetes_cluster.kubernetes_cluster ]
}

resource "kubectl_manifest" "cs_persistance_claim" {
  yaml_body = file("../k8s-cloud/cs/cs-persistancevolumeclaim.yaml")
  depends_on = [ kubectl_manifest.cs_volume ]
}

resource "kubectl_manifest" "cs_job" {
  yaml_body = file("../k8s-cloud/cs/cs-job.yaml")
  depends_on = [ kubectl_manifest.cs_persistance_claim ]
}
