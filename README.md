# 🚀 DevOps Challenge - API REST Django en Azure AKS

[![Infrastructure Pipeline](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/infra-terraform-aks.yaml/badge.svg)](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/infra-terraform-aks.yaml)
[![Application CI/CD](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/app-ci-cd.yaml/badge.svg)](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/app-ci-cd.yaml)

Solución integral para la prueba técnica de DevOps. El proyecto implementa una arquitectura nativa de la nube (*Cloud-Native*) basada en microservicios contenerizados, aprovisionamiento automatizado con **Terraform**, autenticación de seguridad **OIDC (Passwordless)**, despliegue en **Azure Kubernetes Service (AKS)** con alta disponibilidad, y pipelines de entrega continua con **GitHub Actions** y **Makefile**.

---

## 📌 Enlaces Rápidos y Entregables

* **🌐 URL Pública de la API (Producción en vivo):**  
  👉 `http://20.72.147.22/api/users/`
* **⚙️ Pipelines en GitHub Actions (Trazabilidad Pública):**  
  * [Pipeline 1: Infraestructura (Terraform)](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/infra-terraform-aks.yaml)
  * [Pipeline 2: Aplicación y Despliegue (CI/CD)](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/app-ci-cd.yaml)

---

## 🏗️ 1. Arquitectura General del Sistema

El siguiente diagrama describe el flujo automatizado: desde el control de versiones hasta el despliegue en el clúster de Kubernetes en Azure.

```mermaid
graph TD
    subgraph "Desarrollador / Git"
        DEV[Local Dev / DevContainer] -->|git push| GH[GitHub Repository]
    end

    subgraph "Pipelines GitHub Actions"
        GH --> W1[1. Infra Pipeline: Terraform]
        GH --> W2[2. App Pipeline: CI/CD]
        
        W1 -->|OIDC Login| TF[Terraform Apply / State en Blob Storage]
        W2 --> WAIT[Pre-flight Check: Espera Infra]
        WAIT --> LINT[Flake8 & Unit Tests]
        LINT --> COV[Coverage Report]
        COV --> SCAN[Trivy Vulnerability Scan]
        SCAN --> BLD[Docker Build linux/amd64 & Push]
    end

    subgraph "Microsoft Azure Cloud"
        TF -->|Aprovisiona| RG[Resource Group]
        RG --> AKS[Azure Kubernetes Service - AKS]
        RG --> ACR[Azure Container Registry - ACR]
        
        BLD -->|Push de Imagen con SHA| ACR
        AKS -->|AcrPull Managed Identity| ACR
    end

    subgraph "Clúster Kubernetes (Namespace: devsu-app)"
        SVC[LoadBalancer Service: IP Pública] --> POD1[API Pod: Réplica 1]
        SVC --> POD2[API Pod: Réplica 2]
        HPA[Horizontal Pod Autoscaler] -.->|Autoescalado dinámico| POD1
        POD1 --> JOB[Migration Job efímero]
        JOB --> DB[(PostgreSQL StatefulSet / PVC)]
        POD1 --> DB
    end
---
🧠 2. Decisiones de Ingeniería y Arquitectura (Senior Trade-offs)
Para llevar la aplicación base a un entorno productivo real, se aplicaron los siguientes criterios de diseño:
Migración de SQLite a PostgreSQL:
Justificación: SQLite es un archivo plano local incompatible con entornos multi-réplica (replicas >= 2) debido a bloqueos concurrentes de escritura (database is locked) y restricciones de volúmenes en bloque estándar. Se desacopló la base de datos a un servicio dedicado de PostgreSQL 15 respaldado por un disco persistente (PVC), cumpliendo con el principio de Stateless (12-Factor App).
Autenticación Passwordless con Azure OIDC (OpenID Connect):
Seguridad: Se eliminaron los Service Principals con contraseñas estáticas. GitHub Actions e Identity Federation de Microsoft Entra ID negocian tokens criptográficos efímeros de corta duración en cada despliegue.
Desacoplamiento Inteligente con Pre-flight Check:
El pipeline de la aplicación incluye una fase de validación inicial que consulta el estado de Azure y espera de forma automatizada a que la infraestructura de Terraform esté completamente lista antes de iniciar las pruebas y el despliegue.
Paridad Local y CI/CD mediante Makefile:
Las tareas críticas (compilación, pruebas, init de Terraform y despliegue en AKS) están estandarizadas en un Makefile, garantizando que el desarrollador ejecute localmente exactamente lo mismo que corre en la nube.
Aislamiento por Namespaces (devsu-app):
Se evita el uso del namespace default, aplicando gobernanza, segmentación lógica y control del ciclo de vida de los recursos de forma aislada.
📁 3. Estructura del Repositorio
code
Text
├── .devcontainer/              # Entorno de desarrollo aislado en VS Code (Python 3.11 + Postgres)
├── .github/
│   └── workflows/
│       ├── infra-terraform-aks.yaml  # Workflow 1: Aprovisionamiento de AKS y ACR
│       └── app-ci-cd.yaml             # Workflow 2: CI/CD automatizado con pre-flight check
├── app/                        # Código fuente de Django
│   ├── api/                    # Modelos, Vistas, Serializers y Tests
│   ├── demo/                   # Configuración global y Settings de Django
│   └── manage.py               # Utilidad CLI de Django
├── aks/                        # Manifiestos declarativos de Kubernetes (Namespace: devsu-app)
│   ├── 00-namespace.yaml       # Namespace dedicado
│   ├── 01-postgres.yaml        # Deployment + PVC + Service para PostgreSQL
│   ├── 02-configmap.yaml       # Variables de entorno no sensibles
│   ├── 03-secret.yaml          # Secretos de base de datos y Django Secret Key
│   ├── 04-migration-job.yaml   # Job efímero para correr migraciones de forma segura
│   ├── 05-api-deployment.yaml  # Deployment de la API (2 réplicas, Liveness/Readiness probes)
│   ├── 06-api-service.yaml     # Service LoadBalancer (IP Pública en Azure)
│   └── 07-api-hpa.yaml         # Horizontal Pod Autoscaler (Escalado por CPU)
├── infra/                      # Código IaC de Terraform (AKS, ACR, Red)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── Dockerfile                  # Multi-stage Dockerfile de producción (Non-root user + Gunicorn)
├── Makefile                    # Estandarización de comandos para Local y Pipelines
└── requirements.txt            # Dependencias (Django, DRF, Gunicorn, Psycopg2, Coverage)
🛠️ 4. Automatización con Makefile
Comando	Descripción
make test	Ejecuta análisis estático (flake8) y pruebas unitarias con cobertura (coverage).
make backend-init	Crea automáticamente el Resource Group y Storage Account para el tfstate remoto en Azure.
make tf-init	Inicializa Terraform conectándose dinámicamente al backend en Azure Blob Storage.
make tf-plan	Genera el plan de ejecución de infraestructura sin bloqueos interactivos.
make tf-apply	Despliega el clúster AKS y el ACR en Azure.
make app-build-push	Compila la imagen para linux/amd64 y la sube al Azure Container Registry con etiquetas duales (commit SHA y latest).
make app-deploy	Conecta con AKS y aplica los manifiestos ejecutando migraciones seguras y actualización sin caídas (Rolling Update).
🧪 5. Validación y Pruebas del Servicio
1. Consultar Todos los Usuarios (GET)
code
Bash
curl -X GET http://20.72.147.22/api/users/
Respuesta:
code
JSON
[{"id":1,"dni":"12313212313","name":"Elias DevOps"}]
2. Crear un Nuevo Usuario (POST)
code
Bash
curl -X POST http://20.72.147.22/api/users/ \
  -H "Content-Type: application/json" \
  -d '{"dni": "0987654321", "name": "Evaluador DevOps"}'
Respuesta (HTTP 201 Created):
code
JSON
{"id":2,"dni":"0987654321","name":"Evaluador DevOps"}
3. Verificar Recursos en el Clúster
code
Bash
kubectl get pods,svc,hpa -n devsu-app
👤 Autor
Ingeniero DevOps: Romel Tenesaca
Repositorio GitHub: github.com/devrtenesaca/devsu-coderpad