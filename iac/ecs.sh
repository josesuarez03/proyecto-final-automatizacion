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

# Actualizar el sistema e instalar dependencias básicas
log "Actualizando el sistema e instalando dependencias básicas..."
yum update -y
yum install -y \
    ecs-init \
    docker \
    amazon-efs-utils \
    aws-cli \
    jq \
    nfs-utils \
    nc \
    htop \
    systemd-devel \
    wget \
    curl

# Habilitar y arrancar servicios necesarios
log "Configurando servicios..."
systemctl enable docker
systemctl start docker
systemctl enable ecs
systemctl start ecs

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

# Reiniciar el agente de ECS
log "Reiniciando agente ECS..."
systemctl restart ecs

# Obtener metadata de la instancia
log "Obteniendo metadata de la instancia..."
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
S3_BUCKET="artifacts-${ACCOUNT_ID}"

# Crear estructura de directorios para monitoreo
log "Creando estructura de directorios..."
mkdir -p /opt/monitoring/{prometheus,grafana,elk}/{data,config}
mkdir -p /opt/monitoring/grafana/{dashboards,provisioning/{dashboards,datasources}}
mkdir -p /opt/monitoring/elk/{elasticsearch,logstash,kibana}
mkdir -p /opt/monitoring/nginx/logs
mkdir -p /opt/monitoring/mysql/logs
mkdir -p /opt/monitoring/prometheus/rules

# Establecer permisos correctos
log "Configurando permisos..."
# Prometheus
chown -R 65534:65534 /opt/monitoring/prometheus
chmod -R 755 /opt/monitoring/prometheus

# Grafana
chown -R 472:472 /opt/monitoring/grafana
chmod -R 755 /opt/monitoring/grafana

# ELK Stack
chown -R 1000:1000 /opt/monitoring/elk/{elasticsearch,logstash,kibana}
chmod -R 755 /opt/monitoring/elk/{elasticsearch,logstash,kibana}

# Logs
chown -R root:root /opt/monitoring/{nginx,mysql}/logs
chmod -R 755 /opt/monitoring/{nginx,mysql}/logs

# Descargar configuraciones desde S3
log "Descargando configuraciones desde S3..."
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

# Configurar límites del sistema para Elasticsearch
log "Configurando límites del sistema..."
cat <<EOF >> /etc/security/limits.conf
elasticsearch soft nofile 65536
elasticsearch hard nofile 65536
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
EOF

# Configurar sysctl para Elasticsearch
cat <<EOF >> /etc/sysctl.conf
vm.max_map_count=262144
EOF
sysctl -p

# Verificar la instalación
log "Verificando instalación..."
services=(docker ecs)
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        log "$service está corriendo"
    else
        log "ERROR: $service no está corriendo"
        exit 1
    fi
done

# Limpiar
log "Limpiando..."
yum clean all
rm -rf /var/cache/yum

log "Configuración completada exitosamente"