resource "kubernetes_persistent_volume_claim" "jenkins_pvc" {
  metadata {
    name = "jenkins-pvc"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp2"

    resources {
      requests = {
        storage = "20Gi"
      }
    }
  }
}


resource "kubernetes_deployment" "jenkins" {
  metadata {
    name = "jenkins"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "jenkins"
      }
    }

    template {
      metadata {
        labels = {
          app = "jenkins"
        }
      }

      spec {
        security_context {
          run_as_user  = 1000   
          run_as_group = 1000   
          fs_group     = 1000  
        }

        container {
          name  = "jenkins"
          image = "jenkins/jenkins:lts-jdk17"

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "jenkins-home"
            mount_path = "/var/jenkins_home"
          }
        }

        volume {
          name = "jenkins-home"

          persistent_volume_claim {
            claim_name = "jenkins-pvc"
          }
        }
      }
    }
  }
  depends_on = [aws_eks_node_group.eks_node_group]
}


resource "kubernetes_service" "jenkins_loadbalancer" {
  metadata {
    name        = "jenkins-loadbalancer"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"         = "alb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme"       = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-target-type"  = "instance"
    }
  }

  spec {
    selector = {
      app = "jenkins"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}
