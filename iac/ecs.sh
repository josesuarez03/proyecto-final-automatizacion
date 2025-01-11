#!/bin/bash
set -e

# Función para registro de logs
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Función para manejo de errores
handle_error() {
    log "Error en línea $1"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Redirigir salida a un log global
exec > >(tee -i /var/log/setup-script.log)
exec 2>&1

# Crear estructura de directorios
log "Creando estructura de directorios..."
mkdir -p /opt/monitoring/{prometheus,grafana,elk}/{data,config}
mkdir -p /opt/monitoring/grafana/{dashboards,provisioning/{dashboards,datasources}}
mkdir -p /opt/monitoring/elk/{elasticsearch,logstash,kibana}
mkdir -p /opt/monitoring/nginx/logs
mkdir -p /opt/monitoring/mysql/logs
mkdir -p /opt/monitoring/prometheus/rules

# Configurar ECS
log "Configurando ECS..."
mkdir -p /etc/ecs
cat <<EOF > /etc/ecs/ecs.config
ECS_CLUSTER=my-ecs-cluster
ECS_ENGINE_AUTH_TYPE=docker
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
ECS_ENABLE_CONTAINER_METADATA=true
ECS_CONTAINER_INSTANCE_TAGS={"Environment": "production"}
EOF

# Descargar configuraciones desde S3
log "Descargando configuraciones desde S3..."
S3_BUCKET="artifacts-\$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)"
configs=(
    "monitoring/prometheus/prometheus.yml:/opt/monitoring/prometheus/"
    "monitoring/prometheus/rules:/opt/monitoring/prometheus/"
    "monitoring/grafana/provisioning/datasources/datasource.yaml:/opt/monitoring/grafana/provisioning/datasources/"
    "monitoring/grafana/provisioning/dashboards/dashboards.yaml:/opt/monitoring/grafana/provisioning/dashboards/"
    "monitoring/grafana/dashboards:/opt/monitoring/grafana/"
    "monitoring/elk/elasticsearch/elasticsearch.yml:/opt/monitoring/elk/elasticsearch/"
    "monitoring/elk/logstash/logstash.yml:/opt/monitoring/elk/logstash/"
    "monitoring/elk/logstash/pipeline:/opt/monitoring/elk/logstash/"
    "monitoring/elk/kibana/kibana.yml:/opt/monitoring/elk/kibana/"
)

for config in "${configs[@]}"; do
    source_path=${config%:*}
    dest_path=${config#*:}
    log "Descargando $source_path a $dest_path"
    aws s3 cp --recursive "s3://${S3_BUCKET}/${source_path}" "$dest_path" || log "Error descargando $source_path"
done

log "Configuración completada exitosamente"