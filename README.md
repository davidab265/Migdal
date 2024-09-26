
# Project Repository

This repository contains the necessary components to deploy an application on AWS EKS with ArgoCD for GitOps-based continuous deployment.

## Folder Structure

- **app**:  
  Contains the application source code and the Dockerfile used to build the Docker image of the app.
  
- **k8s**:  
  Includes the Kubernetes manifests (YAML files) required to deploy the application on Kubernetes. ArgoCD is used to handle the deployment process.
  
- **argocd**:  
  Contains the ArgoCD Application YAML file, which defines how ArgoCD should monitor and manage the application deployment in the Kubernetes cluster.
  
- **iac**:  
  Infrastructure as Code (IaC) folder that contains Terraform scripts to provision an AWS EKS cluster and deploy ArgoCD to manage the cluster.
  

## Prerequisites
None required for updating the app.
the application is automatically build & deployed via github actions.

- **Terraform**: To provision the infrastructure on AWS.

## CI/CD Pipeline

This repository also includes a GitHub Actions pipeline that automates the following tasks:

1. **Builds the Docker image** for the application using the `Dockerfile` in the `app` folder.
2. **Pushes the Docker image** to a container registry.
3. **Triggers an automated deployment** on the Kubernetes cluster by using ArgoCD, which continuously syncs the latest image and deploys it to the cluster.

This pipeline ensures that every change made to the application is automatically built, tested, and deployed on Kubernetes.


## Testing the pipeline:
To enshure the pipeline is working, make a change in the Html file `app/public/index.html`.
then go to this route: `a0b874b3195a246be9544d3e46049108-829264806.us-east-2.elb.amazonaws.com`
and see if your changes were applied to the application.
