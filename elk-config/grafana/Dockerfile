FROM grafana/grafana:latest

# Crear directorios necesarios
RUN mkdir -p /etc/grafana/provisioning/datasources \
    && mkdir -p /etc/grafana/provisioning/dashboards \
    && mkdir -p /etc/grafana/dashboards

# Copiar archivos de configuración
COPY provisioning/datasources/datasource.yaml /etc/grafana/provisioning/datasources/
COPY provisioning/dashboards/dashboard.yaml /etc/grafana/provisioning/dashboards/
COPY dashboards/node-exporter-full.json /etc/grafana/dashboards/

# Establecer permisos correctos
RUN chown -R grafana:grafana /etc/grafana /var/lib/grafana

EXPOSE 3000

ENV GF_SECURITY_ADMIN_USER=admin \
    GF_SECURITY_ADMIN_PASSWORD=admin \
    GF_PATHS_PROVISIONING=/etc/grafana/provisioning \
    GF_PATHS_DASHBOARDS=/etc/grafana/dashboards

USER grafana

ENTRYPOINT ["/run.sh"]