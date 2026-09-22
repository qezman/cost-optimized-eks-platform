resource "kubernetes_namespace_v1" "main" {
  metadata {
    name = var.namespace
  }
}

# runs the sample web app in the requested namespace
resource "kubernetes_deployment_v1" "main" {
  metadata {
    name      = "sample-web-deployment"
    namespace = kubernetes_namespace_v1.main.metadata[0].name
  }

  spec {
    replicas = var.replicas

    # the selector keeps this deployment connected to its pods
    selector {
      match_labels = {
        app = "sample-web"
      }
    }

    template {
      metadata {
        # this label must match the selector above
        labels = {
          app = "sample-web"
        }
      }

      spec {
        # NGINX serves as the lightweight sample workload
        container {
          name  = "web"
          image = "public.ecr.aws/nginx/nginx:stable"

          port {
            container_port = 80
          }

          # keep requests predictable while limiting peak usage
          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }
        }

      }
    }
  }
}
