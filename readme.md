# Proyecto Final - Automatización CI/CD y DevOps

## Introducción

Este proyecto tiene como objetivo implementar y automatizar un ciclo CI/CD utilizando metodologías DevOps. La aplicación desarrollada es una plataforma de tareas, la cual estará contenerizada y desplegada en AWS (Amazon Web Services) usando ECS (Elastic Container Service). Para la gestión de la infraestructura, se utilizará Terraform, permitiendo un despliegue reproducible y automatizado.

El flujo CI/CD incluirá la ejecución automática de pruebas tanto en el frontend como en el backend cada vez que se realice un commit al repositorio. Además, se utilizará Trello para la gestión de tareas mediante un tablero Agile, facilitando la organización y el seguimiento del proyecto.

La aplicación desarrollada permite a los usuarios gestionar tareas de manera eficiente, incluyendo funcionalidades para añadir, eliminar y marcar tareas como finalizadas.

---

## Objetivos del Proyecto

El principal objetivo fue crear una solución escalable y reproducible para una plataforma de tareas, integrando los siguientes elementos:

- Despliegue automatizado de infraestructura en AWS.
- Contenerización de servicios con Docker.
- Configuración de pipelines CI/CD usando GitHub Actions.
- Pruebas automatizadas para frontend y backend.
- Monitoreo y observabilidad con herramientas como CloudWatch, Prometheus y Grafana.

---

### Plan
1. **Definición de Requisitos:**
   - Se creo un tablero en Trello para definir y asignar tareas. Puedes acceder al tablero de Trello [aquí](https://trello.com/invite/b/6766f2eafc5ae44ba2fbc325/ATTI2e6fca511adf2d3771369a1b60aebfbeCD013F7B/proyecto-final).
   - Identificar los requisitos de la infraestructura y los componentes de la aplicación.
2. **Diseño de la Infraestructura:**
   - Arquitectura basada en contenedores utilizando Docker.
   - Terraform para la definición y despliegue de la infraestructura en AWS.
3. **Configuración del Repositorio:**
   - Estructura del código organizada para frontend (React) y backend (Flask).
   - Configuración inicial de pipelines en el proveedor de CI/CD GitHub Actions.

---

## Arquitectura del Proyecto

La arquitectura fue diseñada para garantizar alta disponibilidad, escalabilidad y eficiencia. Los principales componentes incluyen:

### 1. Infraestructura en AWS

Se utilizó **Terraform** para gestionar la infraestructura como código, abarcando los siguientes recursos:

#### a) VPC y Redes
- **VPC**: Red privada virtual con subredes públicas y privadas para segmentación y seguridad.
- **Subredes**: Configuradas en diferentes zonas de disponibilidad.
- **Grupos de seguridad**: Controlan el acceso a los recursos dentro de la VPC.

#### b) ECS (Elastic Container Service)
Se usó ECS para gestionar contenedores con las siguientes características:
- **Fargate**: Para ejecutar contenedores sin administrar servidores.
- **Task Definitions**: Especifican imágenes Docker, puertos y recursos.
- **Autoescalado**: Ajusta recursos según la carga de trabajo.

#### c) ECR (Elastic Container Registry)
Almacena de forma privada las imágenes Docker.

#### d) ALB (Application Load Balancer)
Distribuye el tráfico entrante hacia los servicios desplegados en ECS.

#### e) EFS (Elastic File System)
Proporciona almacenamiento compartido y persistente entre contenedores.

#### f) S3
Almacena artefactos como logs y configuraciones generadas durante los despliegues.

---

### 2. Contenerización y Servidores

#### a) Docker
- Dockerfiles personalizados para frontend (React) y backend (Flask).
- Imágenes optimizadas para tiempos de construcción y despliegue eficientes.

#### b) Nginx
Servidor web y proxy inverso para el frontend, distribuyendo solicitudes hacia el backend.

---

### 3. Pipeline CI/CD

Se configuraron pipelines en GitHub Actions para automatizar el flujo CI/CD, incluyendo:

#### a) Construcción
- Construcción de imágenes Docker personalizadas.
- Subida de las imágenes al repositorio ECR.

#### b) Pruebas
- **Frontend**: Pruebas unitarias y funcionales con React Testing Library.
- **Backend**: Pruebas unitarias con Pytest.

#### c) Despliegue
- Despliegue en un entorno de staging.
- Promoción automatizada a producción tras aprobación de pull requests o commits.

---

### 4. Monitoreo y Observabilidad

#### a) CloudWatch
- Monitoreo de métricas y logs.
- Alarmas configuradas para detectar anomalías.

#### b) Prometheus y Grafana
- **Prometheus**: Recolección de métricas en tiempo real.
- **Grafana**: Visualización de métricas mediante dashboards personalizados.

---

# Implementación de Servicios ECS

La implementación de servicios ECS en este proyecto se centra en configurar un entorno altamente eficiente y seguro, utilizando capacidades nativas de AWS para gestionar contenedores y asegurar una infraestructura escalable. La configuración se basa en recursos clave definidos mediante código con Terraform, incluyendo clusters ECS, balanceadores de carga, almacenamiento persistente, y servicios de descubrimiento.

## Arquitectura del Cluster ECS

### 1. Configuración del Cluster ECS
El cluster ECS principal se llama `monitoring-cluster` y utiliza las siguientes características:

- **Container Insights:** Habilitado para recolectar métricas y logs de los contenedores.
- **Ejecución de Comandos:** Configuración personalizada que permite capturar logs de comandos ejecutados en los contenedores utilizando CloudWatch.

```hcl
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "monitoring-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name    = "/aws/ecs/monitoring-cluster"
      }
    }
  }

  tags = {
    Environment = var.environment
    Managed_by  = "Terraform"
  }
}
```

### 2. Capacity Providers
Se implementan proveedores de capacidad para optimizar costos y garantizar flexibilidad en el uso de recursos:

- **FARGATE:** Proporciona recursos bajo demanda con alta disponibilidad.
- **FARGATE_SPOT:** Reduce costos utilizando capacidad no utilizada de AWS.

```hcl
resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 70
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    weight            = 30
    capacity_provider = "FARGATE_SPOT"
  }
}
```

### 3. Descubrimiento de Servicios
Se configura un espacio de nombres DNS privado para facilitar la comunicación entre servicios.

```hcl
resource "aws_service_discovery_private_dns_namespace" "monitoring" {
  name        = "monitoring.local"
  description = "Service discovery namespace for monitoring services"
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "api" {
  name = "api"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.monitoring.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
```

## Almacenamiento Persistente con EFS
Se utiliza Amazon Elastic File System (EFS) para proporcionar almacenamiento compartido y persistente a los contenedores:

- **Transición automática a almacenamiento de menor costo:** Después de 30 días de inactividad.
- **Access Points:** Configurados para diferentes componentes como MySQL, Nginx y Prometheus.

```hcl
resource "aws_efs_file_system" "monitoring_data" {
  creation_token = "monitoring-data"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "MonitoringData"
  }
}
```

## Definiciones de Tareas ECS

### API y Nginx
La definición de tareas incluye:
- Contenedores para la API, Nginx y herramientas de monitoreo como Prometheus y Grafana.
- Volúmenes EFS para almacenar datos y logs.

```hcl
resource "aws_ecs_task_definition" "api_stack" {
  family                   = "api-stack"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "2048"
  memory                   = "4096"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "nginx_logs"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.monitoring_data.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.nginx_logs.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${data.aws_ecr_repository.docker.repository_url}:api"
      cpu       = 256
      memory    = 512
      essential = true
      environment = [
        { name = "DB_HOST", value = "mariadb.monitoring.local" },
        { name = "DB_USER", value = "admin" },
        { name = "DB_PASSWORD", value = "1234" },
        { name = "DB_NAME", value = "task_app" }
      ]
      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/api-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    },
    {
      name      = "nginx"
      image     = "${data.aws_ecr_repository.docker.repository_url}:nginx"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      dependsOn = [
        {
          containerName = "api"
          condition     = "START"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "nginx_logs"
          containerPath = "/var/log/nginx"
          readOnly      = false
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/api-stack"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "nginx"
        }
      }
    }
  ])
}
```

### MariaDB
Se utiliza una definición de tarea separada para gestionar MariaDB con configuración de replicación de logs y almacenamiento persistente.

```hcl
resource "aws_ecs_task_definition" "mariadb_stack" {
  family                   = "mariadb-stack"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "mysql_data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.monitoring_data.id
      transit_encryption      = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.mysql_data.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "mariadb"
      image     = "public.ecr.aws/docker/library/mariadb:10.6"
      cpu       = 1024
      memory    = 2048
      essential = true
      environment = [
        { name = "MARIADB_ROOT_PASSWORD", value = "root" },
        { name = "MYSQL_PASSWORD", value = "1234" },
        { name = "MYSQL_DATABASE", value = "task_app" },
        { name = "MYSQL_USER", value = "admin" }
      ]
    }
  ])
}
```


## Servicios ECS: MariaDB y API

### Servicio MariaDB

El servicio **mariadb_services** se encarga de desplegar y gestionar la base de datos MariaDB en ECS. Este servicio asegura la alta disponibilidad y escalabilidad del almacenamiento persistente utilizando Amazon EFS. 

```hcl
resource "aws_ecs_service" "mariadb_services" {
  name            = "mariadb-services"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.mariadb_stack.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.app[*].id
    security_groups = [aws_security_group.mariadb.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mariadb_tg.arn
    container_name   = "mariadb"
    container_port   = 3306
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Environment = var.environment
  }
}
```

### Servicio API

El servicio **api_services** implementa la API y el servidor Nginx, gestionados como contenedores ECS para ofrecer una infraestructura resiliente y eficiente. Este servicio utiliza balanceadores de carga para distribuir el tráfico y garantizar la disponibilidad.

```hcl
resource "aws_ecs_service" "api_services" {
  name            = "api-services"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.api_stack.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.app[*].id
    security_groups = [aws_security_group.api.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_tg.arn
    container_name   = "nginx"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Environment = var.environment
  }
}
```

## Herramientas Usadas

- **Frontend**: React y Tailwind CSS, para una interfaz de usuario moderna y responsiva.
- **Backend**: Python (Flask), para construir una API robusta y ligera.
- **Infraestructura**: Terraform, para definir y desplegar recursos en AWS de manera automatizada.
- **CI/CD**: GitHub Actions, para implementar pipelines que garantizan calidad y velocidad en los despliegues.



## Conclusión

Este proyecto demostró la efectividad de implementar una plataforma CI/CD automatizada con un enfoque DevOps. La arquitectura basada en AWS ECS y Fargate permite escalar los servicios según la demanda, mientras que las herramientas de monitoreo aseguran un seguimiento constante del rendimiento y la disponibilidad.


## Link
- **Otro link al tablero de trello** [aqui](https://trello.com/b/fuOl9aA8/proyecto-final)

## Referencias
- [Ver referencias](resources.md)