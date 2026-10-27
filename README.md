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


## 📂 Estructura del Proyecto

A continuación se detalla la organización de los archivos y directorios principales del repositorio:

```text
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
```