#!/bin/bash
set -e

# Función para registro de logs
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Función para manejo de errores
handle_error() {
    log "Error en línea $1: $2"
    exit 1
}

# Función para verificar el resultado de los comandos
check_command() {
    if [ $? -ne 0 ]; then
        handle_error $1 "Comando fallido: $2"
    fi
}

trap 'handle_error ${LINENO} "${BASH_COMMAND}"' ERR

# Redirigir salida a un log global
exec > >(tee -i /var/log/setup-script.log)
exec 2>&1

# Verificar si el script se está ejecutando como root
if [ "$EUID" -ne 0 ]; then
    log "Este script debe ejecutarse como root o con sudo"
    exit 1
fi

# Actualizar e instalar dependencias necesarias
log "Actualizando sistema e instalando dependencias..."
yum update -y
check_command $LINENO "yum update"

# Instalar dependencias con --allowerasing para resolver conflictos
log "Instalando dependencias básicas..."
yum install -y --allowerasing jq curl aws-cli
check_command $LINENO "instalación de dependencias"

# Instalar Docker
log "Instalando Docker..."
yum install -y docker
check_command $LINENO "instalación de Docker"

systemctl enable docker
check_command $LINENO "habilitar Docker"

systemctl start docker
check_command $LINENO "iniciar Docker"

# Agregar usuario actual al grupo docker si no está en modo root
if [ "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
    check_command $LINENO "agregar usuario al grupo docker"
fi

# Instalar el Agente ECS
log "Instalando el Agente ECS..."
yum install -y ecs-init
check_command $LINENO "instalación de ecs-init"

# Configurar el Agente ECS
log "Configurando el Agente ECS..."
mkdir -p /etc/ecs
check_command $LINENO "crear directorio ECS"

cat > /etc/ecs/ecs.config <<EOF
ECS_CLUSTER=my-ecs-cluster
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
ECS_ENABLE_CONTAINER_METADATA=true
ECS_CONTAINER_INSTANCE_TAGS={"Environment": "production"}
EOF
check_command $LINENO "crear archivo de configuración ECS"

systemctl enable ecs
check_command $LINENO "habilitar ECS"

systemctl start ecs
check_command $LINENO "iniciar ECS"

# Obtener el ID de la cuenta AWS con reintentos
log "Obteniendo el ID de la cuenta de AWS..."
max_attempts=3
attempt=1
while [ $attempt -le $max_attempts ]; do
    log "Intento $attempt de $max_attempts para obtener el ID de cuenta AWS"
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    AWS_ACCOUNT_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
    
    if [[ -n "$AWS_ACCOUNT_ID" ]]; then
        log "ID de cuenta AWS obtenido: $AWS_ACCOUNT_ID"
        break
    fi
    
    attempt=$((attempt + 1))
    [ $attempt -le $max_attempts ] && sleep 5
done

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
    handle_error $LINENO "No se pudo obtener el ID de la cuenta de AWS después de $max_attempts intentos"
fi

# Definir el bucket S3
S3_BUCKET="artifacts-$AWS_ACCOUNT_ID"

# Crear estructura de directorios
log "Creando estructura de directorios..."
directories=(
    "/opt/monitoring/prometheus/data"
    "/opt/monitoring/prometheus/config"
    "/opt/monitoring/grafana/data"
    "/opt/monitoring/grafana/config"
    "/opt/monitoring/grafana/dashboards"
    "/opt/monitoring/grafana/provisioning/dashboards"
    "/opt/monitoring/grafana/provisioning/datasources"
    "/opt/monitoring/elk/elasticsearch"
    "/opt/monitoring/elk/logstash"
    "/opt/monitoring/elk/kibana"
    "/opt/monitoring/nginx/logs"
    "/opt/monitoring/mysql/logs"
    "/opt/monitoring/prometheus/rules"
)

for dir in "${directories[@]}"; do
    mkdir -p "$dir"
    check_command $LINENO "crear directorio $dir"
done

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
    aws s3 cp --recursive "s3://${S3_BUCKET}/${source_path}" "$dest_path" || log "Advertencia: Error descargando $source_path"
done

log "Instalación y configuración completadas exitosamente."
log "IMPORTANTE: Si no estás usando root directamente, reinicia la sesión para aplicar los cambios del grupo Docker."