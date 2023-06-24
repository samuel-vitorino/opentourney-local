
output "cluster-id" {
  value = digitalocean_kubernetes_cluster.kubernetes_cluster.id
}

output "endpoint" {
  value = digitalocean_kubernetes_cluster.kubernetes_cluster.endpoint
}