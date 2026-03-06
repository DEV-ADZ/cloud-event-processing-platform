currently working on this project. the aim is to develop a Cloud-native event processing platform demonstrating REST APIs, Docker containerisation, Kubernetes orchestration, CI/CD with GitHub Actions, infrastructure provisioning with Terraform on AWS (EKS), autoscaling, monitoring with Prometheus & Grafana, and centralized logging.


CI/CD 
Github actions pipeline runs on every push to main:
it
1. Checks out the repository
2. Installs Python dependencies
3. Builds the Docker image for  API
4. Tags the image using the commit SHA
5. Rewrites the Kubernetes deployment manifest during the pipeline