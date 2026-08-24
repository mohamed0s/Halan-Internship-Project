FROM bitnami/nginx:latest

# Switch to root temporarily to copy files
USER root

# Copy static frontend files into the Bitnami nginx html directory
COPY src/ /usr/share/nginx/html/

# Bitnami nginx runs as non-root user 1001 on port 8080
# The serverBlock (reverse proxy config) is injected by the Helm chart via values.yaml
# so we do NOT copy nginx.conf here — the chart handles it
USER 1001

EXPOSE 8080
