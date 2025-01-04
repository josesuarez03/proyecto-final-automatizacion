#!/bin/bash
# Actualizar el sistema e instalar ECS
yum update -y
yum install -y ecs-init docker
systemctl enable --now docker
systemctl enable --now ecs

cat <<EOF >> /etc/ecs/ecs.config
ECS_CLUSTER=my-ecs-cluster
ECS_CONTAINER_INSTANCE_TAGS={"Environment":"production","Project":"ecs"}
ECS_CONTAINER_INSTANCE_PROPAGATE_TAGS_FROM=ec2_instance
EOF

# Reiniciar el agente de ECS
systemctl restart ecs

# Instalar herramientas necesarias para los volumenes
yum install -y amazon-efs-utils

# Actualizar el sistema e instalar herramientas necesarias
yum install -y aws-cli jq

# Obtener el ID de la cuenta de AWS
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .accountId)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)
S3_BUCKET="artifacts-${ACCOUNT_ID}"

# Crear directorios para las configuraciones
mkdir -p /opt/monitoring/{prometheus,grafana/{dashboards,provisioning/{dashboards,datasources}},elk/{elasticsearch,logstash,kibana}}

# Establecer permisos para los directorios
chown -R 65534:65534 /opt/monitoring/prometheus
chmod -R 755 /opt/monitoring/prometheus
chown -R 472:472 /opt/monitoring/grafana
chmod -R 755 /opt/monitoring/grafana
chown -R 1000:1000 /opt/monitoring/elk/{elasticsearch,logstash,kibana}
chmod -R 755 /opt/monitoring/elk/{elasticsearch,logstash,kibana}

# Descargar configuraciones desde S3
aws s3 cp s3://${S3_BUCKET}/monitoring/prometheus/prometheus.yml /opt/monitoring/prometheus/ || echo "Error downloading prometheus config"
aws s3 cp s3://${S3_BUCKET}/monitoring/grafana/provisioning/datasources/datasource.yaml /opt/monitoring/grafana/provisioning/datasources/ || echo "Error downloading datasource config"
aws s3 cp s3://${S3_BUCKET}/monitoring/elk/elasticsearch/elasticsearch.yml /opt/monitoring/elk/elasticsearch/ || echo "Error downloading elasticsearch config"
aws s3 cp s3://${S3_BUCKET}/monitoring/elk/logstash/logstash.yml /opt/monitoring/elk/logstash/ || echo "Error downloading logstash config"
aws s3 cp s3://${S3_BUCKET}/monitoring/elk/kibana/kibana.yml /opt/monitoring/elk/kibana/ || echo "Error downloading kibana config"