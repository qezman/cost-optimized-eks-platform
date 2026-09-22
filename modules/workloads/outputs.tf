output "namespace_name" {
  value = kubernetes_namespace_v1.main.metadata[0].name
}
