#!/bin/bash
# Configurar el cluster de ECS
echo ECS_CLUSTER=my-ecs-cluster >> /etc/ecs/ecs.config

# Actualizar el sistema e instalar herramientas necesarias
yum update -y
yum install -y aws-cli jq

# Obtener el ID de la cuenta de AWS
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
S3_BUCKET="artifacts-${ACCOUNT_ID}"

# Crear directorios para las configuraciones con los permisos adecuados
mkdir -p /opt/monitoring/prometheus
mkdir -p /opt/monitoring/grafana/dashboards
mkdir -p /opt/monitoring/grafana/provisioning/dashboards
mkdir -p /opt/monitoring/grafana/provisioning/datasources
mkdir -p /opt/monitoring/elk/elasticsearch
mkdir -p /opt/monitoring/elk/logstash
mkdir -p /opt/monitoring/elk/kibana

# Descargar configuraciones desde S3
aws s3 cp s3://${S3_BUCKET}/monitoring/prometheus/prometheus.yml /opt/monitoring/prometheus/ || echo "Error downloading prometheus config"
aws s3 cp s3://${S3_BUCKET}/monitoring/grafana/dashboards/node-exporter-full.json /opt/monitoring/grafana/dashboards/ || echo "Error downloading grafana dashboard"
aws s3 cp s3://${S3_BUCKET}/monitoring/grafana/provisioning/dashboards/dashboard.yaml /opt/monitoring/grafana/provisioning/dashboards/ || echo "Error downloading dashboard config"
aws s3 cp s3://${S3_BUCKET}/monitoring/grafana/provisioning/datasources/datasource.yaml /opt/monitoring/grafana/provisioning/datasources/ || echo "Error downloading datasource config"
aws s3 cp s3://${S3_BUCKET}/monitoring/elk/elasticsearch/elasticsearch.yml /opt/monitoring/elk/elasticsearch/ || echo "Error downloading elasticsearch config"
aws s3 cp s3://${S3_BUCKET}/monitoring/elk/logstash/logstash.yml /opt/monitoring/elk/logstash/ || echo "Error downloading logstash config"
aws s3 cp s3://${S3_BUCKET}/monitoring/elk/logstash/logstash.conf /opt/monitoring/elk/logstash/ || echo "Error downloading logstash pipeline"
aws s3 cp s3://${S3_BUCKET}/monitoring/elk/kibana/kibana.yml /opt/monitoring/elk/kibana/ || echo "Error downloading kibana config"

# Establecer permisos para los directorios
# Prometheus necesita acceso de escritura para sus datos
chown -R 65534:65534 /opt/monitoring/prometheus  # Usuario nobody para Prometheus
chmod -R 755 /opt/monitoring/prometheus

# Grafana necesita permisos específicos
chown -R 472:472 /opt/monitoring/grafana  # Usuario grafana
chmod -R 755 /opt/monitoring/grafana

# Elasticsearch necesita permisos específicos
chown -R 1000:1000 /opt/monitoring/elk/elasticsearch  # Usuario elasticsearch
chmod -R 755 /opt/monitoring/elk/elasticsearch

# Logstash necesita permisos específicos
chown -R 1000:1000 /opt/monitoring/elk/logstash  # Usuario logstash
chmod -R 755 /opt/monitoring/elk/logstash

# Kibana necesita permisos específicos
chown -R 1000:1000 /opt/monitoring/elk/kibana  # Usuario kibana
chmod -R 755 /opt/monitoring/elk/kibana

# Verificar que los archivos se descargaron correctamente
echo "Verificando archivos descargados..."
ls -la /opt/monitoring/prometheus/
ls -la /opt/monitoring/grafana/
ls -la /opt/monitoring/elk/