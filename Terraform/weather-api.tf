resource "kubernetes_service" "weather_api_loadbalancer" {
  metadata {
    name = "weather-api-loadbalancer"

    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"        = "alb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"      = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-target-type" = "instance"
    }
  }

  spec {
    selector = {
      app = "weather-api"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8000
    }

    type = "LoadBalancer"
  }
}


# Secret
resource "kubernetes_secret" "opencage_api_key" {
  metadata {
    name      = "opencage-api-key"
    namespace = "default"
  }

  data = {
    OPENCAGE_API_KEY = #Redacted
  }
}



# ClusterIP

resource "kubernetes_service" "weather_api_internal_service" {
  metadata {
    name      = "weather-api-internal-service"
    namespace = "default"
  }

  spec {
    selector = {
      app =  "weather-api"
    }

    port {
      protocol   = "TCP"
      port       = 8000
      target_port = 8000
    }

    type = "ClusterIP"
  }
}
