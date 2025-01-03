# Obtener el ID de la cuenta de AWS actual
data "aws_caller_identity" "current" {}

# Bucket S3 para todos los artefactos
resource "aws_s3_bucket" "artifacts" {
  bucket = "artifacts-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "Project Artifacts"
    Environment = var.environment
    Managed_by  = "Terraform"
  }
}

# Habilitar versionamiento
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Configurar encriptación
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acceso público
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Backend artifacts
resource "aws_s3_object" "backend_source" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "backend/source/api.tar.gz"
  source = "${path.module}/../../backend/api.tar.gz"
  etag   = filemd5("${path.module}/../../backend/api.tar.gz")
}

resource "aws_s3_object" "backend_requirements" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "backend/requirements.txt"
  source = "${path.module}/../../backend/requirements.txt"
  etag   = filemd5("${path.module}/../../backend/requirements.txt")
}

resource "aws_s3_object" "backend_dockerfile" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "backend/Dockerfile"
  source = "${path.module}/../../backend/Dockerfile"
  etag   = filemd5("${path.module}/../../backend/Dockerfile")
}

# Frontend artifacts
resource "aws_s3_object" "frontend_dist" {
  for_each = fileset("${path.module}/../../frontend/dist", "**/*")
  bucket   = aws_s3_bucket.artifacts.id
  key      = "frontend/dist/${each.value}"
  source   = "${path.module}/../../frontend/dist/${each.value}"
  etag     = filemd5("${path.module}/../../frontend/dist/${each.value}")
  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "svg"  = "image/svg+xml"
  }, length(split(".", each.value)) > 1 ? lower(split(".", each.value)[length(split(".", each.value)) - 1]) : "binary/octet-stream", "binary/octet-stream")
}

resource "aws_s3_object" "frontend_nginx_conf" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "frontend/nginx.conf"
  source = "${path.module}/../../frontend/nginx.conf"
  etag   = filemd5("${path.module}/../../frontend/nginx.conf")
}

resource "aws_s3_object" "frontend_dockerfile" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "frontend/Dockerfile"
  source = "${path.module}/../../frontend/Dockerfile"
  etag   = filemd5("${path.module}/../../frontend/Dockerfile")
}

# Monitoring artifacts
resource "aws_s3_object" "prometheus_config" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/prometheus/prometheus.yml"
  source = "${path.module}/../../prometheus.yml"
  etag   = filemd5("${path.module}/../../prometheus.yml")
}

# Configuración de ELK Stack
resource "aws_s3_object" "elasticsearch_config" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/elk/elasticsearch/elasticsearch.yml"
  source = "${path.module}/../../elk-config/elasticsearch/elasticsearch.yml"
  etag   = filemd5("${path.module}/../../elk-config/elasticsearch/elasticsearch.yml")
}

resource "aws_s3_object" "kibana_config" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/elk/kibana/kibana.yml"
  source = "${path.module}/../../elk-config/kibana/kibana.yml"
  etag   = filemd5("${path.module}/../../elk-config/kibana/kibana.yml")
}

resource "aws_s3_object" "logstash_config" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/elk/logstash/logstash.yml"
  source = "${path.module}/../../elk-config/logstash/logstash.yml"
  etag   = filemd5("${path.module}/../../elk-config/logstash/logstash.yml")
}

resource "aws_s3_object" "logstash_pipeline" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/elk/logstash/logstash.conf"
  source = "${path.module}/../../elk-config/logstash/logstash.conf"
  etag   = filemd5("${path.module}/../../elk-config/logstash/logstash.conf")
}

# Configuración de Grafana
resource "aws_s3_object" "grafana_dashboard" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/grafana/dashboards/node-exporter-full.json"
  source = "${path.module}/../../elk-config/grafana/dashboards/node-exporter-full.json"
  etag   = filemd5("${path.module}/../../elk-config/grafana/dashboards/node-exporter-full.json")
}

resource "aws_s3_object" "grafana_dashboard_config" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/grafana/provisioning/dashboards/dashboard.yaml"
  source = "${path.module}/../../elk-config/grafana/provisioning/dashboards/dashboard.yaml"
  etag   = filemd5("${path.module}/../../elk-config/grafana/provisioning/dashboards/dashboard.yaml")
}

resource "aws_s3_object" "grafana_datasource" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "monitoring/grafana/provisioning/datasources/datasource.yaml"
  source = "${path.module}/../../elk-config/grafana/provisioning/datasources/datasource.yaml"
  etag   = filemd5("${path.module}/../../elk-config/grafana/provisioning/datasources/datasource.yaml")
}

# Add bucket access to ECS task role
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "ecs_task_s3_access"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}