# 🚀 DevOps Challenge - API REST Django en Azure AKS

[![Infrastructure Pipeline](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/infra-terraform-aks.yaml/badge.svg)](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/infra-terraform-aks.yaml)
[![Application CI/CD](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/app-ci-cd.yaml/badge.svg)](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/app-ci-cd.yaml)

Solución técnica para la prueba práctica de DevOps. La arquitectura implementa aprovisionamiento con **Terraform**, autenticación segura **OIDC (Passwordless)**, contenedorización optimizada para producción con **Docker**, despliegue en **Azure Kubernetes Service (AKS)** con alta disponibilidad, y pipelines automatizados mediante **GitHub Actions** y **Makefile**.

---

## 📌 Enlaces Rápidos y Entregables

* **🌐 URL Pública de la API (Producción):**  
  👉 `http://<TU_IP_PUBLICA_DE_AZURE>/api/users/`
* **⚙️ Pipelines de GitHub Actions (Ejecuciones Públicas):**  
  * [Pipeline 1: Infraestructura (Terraform)](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/infra-terraform-aks.yaml)
  * [Pipeline 2: Aplicación y Despliegue](https://github.com/devrtenesaca/devsu-coderpad/actions/workflows/app-ci-cd.yaml)

---

## 🏗️ 1. Arquitectura General del Sistema

El siguiente diagrama describe el flujo de extremo a extremo: desde el código fuente hasta la entrega en el clúster de Kubernetes en Azure.

```mermaid
graph TD
    subgraph "Desarrollador"
        DEV[Local Dev / DevContainer] -->|git push| GH[GitHub Repository]
    end

    subgraph "GitHub Actions CI/CD"
        GH --> W1[1. Infra Pipeline: Terraform]
        GH --> W2[2. App Pipeline: CI/CD]
        
        W1 -->|OIDC Login| TF[Terraform Apply]
        W2 --> LINT[Flake8 & Unit Tests]
        LINT --> COV[Coverage Report]
        COV --> SCAN[Trivy Vulnerability Scan]
        SCAN --> BLD[Docker Build & Push]
    end

    subgraph "Microsoft Azure Cloud"
        TF -->|Aprovisiona| RG[Resource Group]
        RG --> AKS[Azure Kubernetes Service - AKS]
        RG --> ACR[Azure Container Registry - ACR]
        RG --> ST[Storage Account: Remote State]
        
        BLD -->|Push Imagen| ACR
        AKS -->|AcrPull Managed Identity| ACR
    end

    subgraph "Clúster Kubernetes (AKS)"
        SVC[LoadBalancer Service: IP Pública] --> ING[API Pod: Réplica 1]
        SVC --> ING2[API Pod: Réplica 2]
        HPA[Horizontal Pod Autoscaler] -.->|Autoescalado| ING
        ING --> DB[(PostgreSQL StatefulSet / PVC)]
        ING2 --> DB
    end

    🧠 2. Decisiones de Ingeniería y Arquitectura (Senior Trade-offs)
Para convertir el proyecto base en una solución 100% lista para producción, se tomaron las siguientes decisiones de diseño:
1. Migración de Base de Datos: SQLite ➔ PostgreSQL
Problema: SQLite es una base de datos basada en un único archivo en disco. En Kubernetes con múltiples réplicas (replicas >= 2), SQLite genera bloqueos concurrentes de escritura (database is locked) y no es compatible con volúmenes en bloque estándar (ReadWriteOnce).
Solución: Se desacopló la base de datos a un servicio de PostgreSQL 15 dentro del clúster con su propio PersistentVolumeClaim (PVC). Esto garantiza principios de 12-Factor App (Stateless) y transacciones ACID seguras entre múltiples réplicas.
2. Autenticación Passwordless con GitHub OIDC (OpenID Connect)
Seguridad: En lugar de crear un Service Principal con contraseñas estáticas que expiran en Azure, se configuró Workload Identity Federation (OIDC). GitHub Actions genera tokens criptográficos efímeros de corta duración validados directamente por Microsoft Entra ID.
3. Desacoplamiento de Pipelines (Infraestructura vs Aplicación)
Infraestructura (infra-terraform-aks.yaml): Se ejecuta solo ante cambios en la carpeta infra/ o bajo demanda. Evita esperar los 10 minutos de validación de AKS en cada commit del código fuente.
Aplicación (app-ci-cd.yaml): Rápido, enfocado en pruebas unitarias, escaneo estático de seguridad y despliegue continuo (Rolling Updates).
4. Docker Multi-Stage y Principio de Menor Privilegio
Se implementó un Dockerfile con construcción en múltiples etapas (Multi-stage build), reduciendo la superficie de ataque.
El contenedor corre bajo un usuario sin privilegios appuser (UID 10001), evitando vulnerabilidades de escalación de privilegios en el nodo.
Se reemplazó runserver por Gunicorn como servidor WSGI de producción.
5. Simplicidad Cloud-Native: ¿Por qué no Ansible para K8s?
Se evaluó el uso de Ansible para el despliegue en AKS; sin embargo, en un clúster gestionado donde no se administra el sistema operativo de las VMs, usar Ansible para envolver manifiestos de Kubernetes genera redundancia (YAML wrapping YAML). Se prefirió el uso directo de herramientas nativas de Kubernetes y Makefile, manteniendo el pipeline limpio y trazable.

📁 3. Estructura del Repositorio

├── .devcontainer/              # Entorno de desarrollo aislado en VS Code
├── .github/
│   └── workflows/
│       ├── infra-terraform-aks.yaml  # Workflow 1: Aprovisionamiento AKS
│       └── app-ci-cd.yaml             # Workflow 2: CI/CD de la aplicación
├── api/                        # Aplicación Django (Modelos, Vistas, Serializers)
├── demo/                       # Configuración global del proyecto Django
├── infra/                      # Código IaC de Terraform (AKS, ACR, Red)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── k8s/                        # Manifiestos declarativos de Kubernetes
│   ├── postgres.yaml           # Deployment + PVC + Service para Postgres
│   ├── configmap.yaml          # Variables no sensibles de Django
│   ├── secret.yaml             # Secretos de base de datos y Django Secret Key
│   ├── deployment.yaml         # Deployment de la API (2 réplicas + Probes)
│   ├── service.yaml            # Service LoadBalancer (IP Pública en Azure)
│   └── hpa.yaml                # Horizontal Pod Autoscaler (Escalado CPU)
├── Dockerfile                  # Multi-stage Dockerfile de producción
├── Makefile                    # Estandarización de comandos para Local y CI/CD
└── requirements.txt            # Dependencias de Python