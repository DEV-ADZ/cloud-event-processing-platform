# Cloud-Native Event Processing Platform (AWS EKS + Terraform)

A production-style cloud platform that processes events through a containerised API deployed on **Amazon EKS**, with infrastructure fully provisioned using **Terraform**.

The project demonstrates how a locally containerised **Flask + PostgreSQL** application can be migrated from **Docker Compose** to a scalable cloud architecture running on **AWS Kubernetes infrastructure**.

The system includes:

- Infrastructure as Code using **Terraform**
- A secure **AWS VPC with public and private subnets**
- A **managed Kubernetes cluster (Amazon EKS)**
- **Docker containers stored in Amazon ECR**
- Internet traffic routed through an **AWS Application Load Balancer**
- **TLS encryption using AWS Certificate Manager**
- **Automatic scaling using Kubernetes Horizontal Pod Autoscaler**
- **CI/CD pipeline using GitHub Actions**

The platform simulates a **real production cloud architecture**, demonstrating how modern distributed systems are deployed, secured, scaled, and monitored.

---

# Project Architecture

The platform is built using modern cloud-native technologies.

### Core Technologies

**Infrastructure**

- Terraform
- AWS VPC
- Public and Private Subnets
- Internet Gateway
- NAT Gateway

**Container Platform**

- Amazon EKS (Kubernetes)
- Docker
- Helm

**Application**

- Python (Flask API)
- PostgreSQL

**Container Registry**

- Amazon ECR

**Networking**

- AWS Load Balancer Controller
- Kubernetes Ingress
- Application Load Balancer (ALB)

**Security**

- AWS IAM
- IAM Roles for Service Accounts (IRSA)
- AWS Certificate Manager (ACM)

**Scaling & Observability**

- Horizontal Pod Autoscaler
- Metrics Server

---

# Infrastructure Provisioning

Infrastructure is fully provisioned using **Terraform**, creating:

- A **VPC spanning multiple availability zones**
- **Public and private subnets** for secure networking
- An **Internet Gateway** for inbound traffic
- A **NAT Gateway** enabling private resources to access the internet
- **IAM roles and policies** for EKS control plane and worker nodes
- **Amazon ECR repositories** for container images
- A **managed Amazon EKS cluster with worker node groups**

This approach ensures the entire cloud environment can be recreated reproducibly using Infrastructure as Code.

---

# Kubernetes Deployment

The application is deployed to the EKS cluster using Kubernetes manifests.

The deployment includes:

- **Deployment** for running multiple API pods
- **ClusterIP Service** for internal communication
- **Ingress resource** managed by the AWS Load Balancer Controller
- **Horizontal Pod Autoscaler** for automatic scaling

---

# Request Flow

Incoming traffic flows through the system as follows:

```
Internet
   ↓
AWS Application Load Balancer
   ↓
Kubernetes Ingress
   ↓
ClusterIP Service
   ↓
Application Pods
   ↓
PostgreSQL Database
```

---

# Autoscaling

The system automatically scales application pods based on CPU utilisation.

Metrics are collected by the **Kubernetes metrics-server**, allowing the **Horizontal Pod Autoscaler** to increase or decrease the number of running pods depending on load.

---

# Security

Several security best practices are implemented:

- Worker nodes run in **private subnets without public IP addresses**
- IAM Roles for Service Accounts (**IRSA**) enforce **least-privilege permissions**
- **TLS certificates managed by AWS Certificate Manager**
- HTTPS enforced via **Application Load Balancer listeners**

---

# CI/CD Pipeline

A **GitHub Actions pipeline** runs on every push to the `main` branch.

The pipeline:

1. Checks out the repository  
2. Installs Python dependencies  
3. Builds the Docker image  
4. Tags the image using the commit SHA  
5. Pushes the image to Amazon ECR  
6. Updates the Kubernetes deployment manifest with the new image version  

This provides a basic **continuous integration and delivery workflow** for container deployments.
