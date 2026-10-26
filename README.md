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