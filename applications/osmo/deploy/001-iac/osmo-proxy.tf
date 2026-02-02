# =============================================================================
# OSMO Proxy LoadBalancer Service
# =============================================================================
# Creates the OSMO namespace and LoadBalancer service in Terraform so that
# the external IP can be output. The nginx deployment is created by the
# shell scripts in 002-setup.

# -----------------------------------------------------------------------------
# OSMO Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "osmo" {
  metadata {
    name = "osmo"
  }

  depends_on = [module.k8s]
}

# -----------------------------------------------------------------------------
# OSMO Proxy ConfigMap (nginx configuration)
# -----------------------------------------------------------------------------
resource "kubernetes_config_map_v1" "osmo_proxy_nginx" {
  metadata {
    name      = "osmo-proxy-nginx-config"
    namespace = kubernetes_namespace_v1.osmo.metadata[0].name
  }

  data = {
    "nginx.conf" = <<-EOF
      events {
        worker_connections 1024;
      }

      http {
        # Logging
        access_log /dev/stdout;
        error_log /dev/stderr;

        # Conditional WebSocket support
        map $http_upgrade $connection_upgrade {
          default upgrade;
          '' close;
        }

        # Upstream servers
        upstream osmo-service {
          server osmo-service.osmo.svc.cluster.local:80;
        }

        upstream osmo-logger {
          server osmo-logger.osmo.svc.cluster.local:80;
        }

        upstream osmo-agent {
          server osmo-agent.osmo.svc.cluster.local:80;
        }

        upstream osmo-ui {
          server osmo-ui.osmo.svc.cluster.local:80;
        }

        upstream keycloak {
          server keycloak.osmo.svc.cluster.local:80;
        }

        server {
          listen 80;

          # Common proxy headers
          proxy_http_version 1.1;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;

          # WebSocket support
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;

          # Timeouts for long-running WebSocket connections
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;

          # Route /api/logger/* to osmo-logger (WebSocket for log streaming)
          location /api/logger/ {
            proxy_pass http://osmo-logger;
          }

          # Route /api/agent/* to osmo-agent (WebSocket for backend communication)
          location /api/agent/ {
            proxy_pass http://osmo-agent;
          }

          # Route /api/* to osmo-service (REST API)
          location /api/ {
            proxy_pass http://osmo-service;
          }

          # Route /auth/* and /realms/* to Keycloak (SSO with Google/Azure AD)
          location /auth/ {
            proxy_pass http://keycloak;
          }

          location /realms/ {
            proxy_pass http://keycloak;
          }

          location /admin/ {
            proxy_pass http://keycloak;
          }

          location /js/ {
            proxy_pass http://keycloak;
          }

          location /resources/ {
            proxy_pass http://keycloak;
          }

          # Route everything else to osmo-ui (Web UI)
          location / {
            proxy_pass http://osmo-ui;
          }
        }
      }
    EOF
  }
}

# -----------------------------------------------------------------------------
# OSMO Proxy Deployment
# -----------------------------------------------------------------------------
resource "kubernetes_deployment_v1" "osmo_proxy" {
  metadata {
    name      = "osmo-proxy"
    namespace = kubernetes_namespace_v1.osmo.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "osmo-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "osmo-proxy"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:alpine"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/nginx.conf"
            sub_path   = "nginx.conf"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }
        }

        volume {
          name = "nginx-config"
          config_map {
            name = kubernetes_config_map_v1.osmo_proxy_nginx.metadata[0].name
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# OSMO Proxy LoadBalancer Service
# -----------------------------------------------------------------------------
resource "kubernetes_service_v1" "osmo_proxy" {
  metadata {
    name      = "osmo-proxy"
    namespace = kubernetes_namespace_v1.osmo.metadata[0].name
  }

  spec {
    selector = {
      app = "osmo-proxy"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment_v1.osmo_proxy]
}
