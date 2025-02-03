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
        # Pod-level security context
        security_context {
          fs_group = 1000 
        }

        # Jenkins container
        container {
          name  = "jenkins"
          image = "eetape/jenkins:lts-jdk17"

          security_context {
            run_as_user  = 1000 
            run_as_group = 1000 
          }

          env {
            name  = "DOCKER_HOST"
            value = "tcp://localhost:2375" # Communicate with Docker-in-Docker sidecar
          }

          port {
            container_port = 8080
          }

          volume_mount {
            name       = "jenkins-workspace"
            mount_path = "/var/jenkins_home"
          }
        }

        # Docker-in-Docker sidecar container
        container {
          name  = "dind"
          image = "docker:dind"

          security_context {
            privileged = true 
          }

          env {
            name  = "DOCKER_TLS_CERTDIR"
            value = "" 
          }

          volume_mount {
            name       = "docker-graph-storage"
            mount_path = "/var/lib/docker"
          }
        }

        # Shared volumes between containers
        volume {
          name = "jenkins-workspace"

          empty_dir {}
        }

        volume {
          name = "docker-graph-storage"

          empty_dir {}
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
    depends_on = [aws_eks_node_group.eks_node_group]
}
