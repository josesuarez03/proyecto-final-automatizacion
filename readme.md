# Proyecto Final de Automatización y Despliegue

### Descripción del Proyecto
Este proyecto tiene como objetivo implementar y automatizar un ciclo CI/CD utilizando metodologías DevOps. La aplicación desarrollada es una plataforma de tareas, la cual estará contenerizada y desplegada en AWS (Amazon Web Services) usando ECS (Elastic Container Service). Para la gestión de la infraestructura, se utilizará Terraform, permitiendo un despliegue reproducible y automatizado.

El flujo CI/CD incluirá la ejecución automática de pruebas tanto en el frontend como en el backend cada vez que se realice un commit al repositorio. Además, se utilizará Trello para la gestión de tareas mediante un tablero Agile, facilitando la organización y el seguimiento del proyecto.

---

### Plan
1. **Definición de Requisitos:**
   - Crear un tablero en Trello para definir y asignar tareas. Puedes acceder al tablero de Trello [aquí](https://trello.com/invite/b/6766f2eafc5ae44ba2fbc325/ATTI2e6fca511adf2d3771369a1b60aebfbeCD013F7B/proyecto-final).
   - Identificar los requisitos de la infraestructura y los componentes de la aplicación.
2. **Diseño de la Infraestructura:**
   - Arquitectura basada en contenedores utilizando Docker.
   - Terraform para la definición y despliegue de la infraestructura en AWS.
3. **Configuración del Repositorio:**
   - Estructura del código organizada para frontend (React) y backend (Flask).
   - Configuración inicial de pipelines en el proveedor de CI/CD GitHub Actions.

---

### Code
- **Frontend:** Desarrollado en React, servido mediante Nginx.
- **Backend:** API RESTful implementada en Flask para manejar las peticiones del frontend hacia la base de datos.
- **Infraestructura:** Configurada y gestionada mediante Terraform.

---

### Build
1. Contenerización del frontend y backend utilizando Docker.
2. Definición de archivos Dockerfile optimizados para cada servicio.
3. Automatización del proceso de construcción en el pipeline CI/CD.

---

### Test
- **Frontend:** Ejecución de pruebas unitarias y de integración utilizando frameworks como Jest o Testing Library.
- **Backend:** Validación mediante pruebas unitarias con pytest y pruebas de integración.
- **Infraestructura:** Verificación de configuraciones de Terraform con herramientas como terraform validate y pruebas con Terratest.

---

### Monitoring and Observability
1. **Monitoreo:**
   - Implementar CloudWatch para monitorear métricas de rendimiento y logs de los servicios.
   - Configurar alertas automáticas en caso de errores o caída de servicios.
2. **Observabilidad:**
   - Integración de herramientas como Prometheus y Grafana para visualización de métricas.

---

### Deploy
1. **Infraestructura:**
   - Despliegue automatizado de recursos en AWS usando Terraform.
   - Configuración de ECS para la gestión de contenedores.
2. **Aplicación:**
   - Despliegue del frontend y backend mediante pipelines CI/CD.
   - Validación del despliegue en un entorno staging antes de la promoción a producción.
3. **Pipeline CI/CD:**
   - Automatización completa: build, test, deploy.
   - Revisión y despliegue continuo en cada commit o pull request.

---

## Herramientas


## Link
- **Otro link al tablero de trello** [aqui](https://trello.com/b/fuOl9aA8/proyecto-final)

## Referencias
- [Ver referencias](resources.md)