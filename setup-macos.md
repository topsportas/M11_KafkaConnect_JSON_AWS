# Setup Guide for macOS

## Prerequisites

1. **Install Required Tools**
   ```bash
   # Install Homebrew if not already installed
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   
   # Install required tools
   brew install awscli
   brew install terraform
   brew install kubectl
   brew install helm
   ```

2. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter your AWS Access Key ID
   # Enter your AWS Secret Access Key
   # Enter your default region (e.g., us-west-1)
   # Enter your output format (json)
   ```

## Deployment Steps

1. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

2. **Create S3 Bucket and DynamoDB Table**
   ```bash
   # Create S3 bucket
   aws s3api create-bucket --bucket m11-kafka --region us-west-1
   
   # Create DynamoDB table
   aws dynamodb create-table \
     --table-name m11-kafka \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
     --region us-west-1
   ```

3. **Apply Terraform Configuration**
   ```bash
   terraform plan -out terraform.plan
   terraform apply terraform.plan
   ```

4. **Configure kubectl**
   ```bash
   # Get cluster name
   CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
   
   # Update kubeconfig
   aws eks update-kubeconfig --name $CLUSTER_NAME --region us-west-1
   
   # Switch to confluent namespace
   kubectl config set-context --current --namespace confluent
   ```

5. **Install Confluent Platform**
   ```bash
   # Add Confluent Helm repository
   helm repo add confluentinc https://packages.confluent.io/helm
   helm repo update
   
   # Install Confluent Operator
   helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes
   
   # Apply Confluent Platform configuration
   kubectl apply -f confluent-platform.yaml
   ```

6. **Build and Push Connector Image**
   ```bash
   # Get ECR repository URL
   ECR_REPO=$(terraform output -raw ecr_repository_url)
   
   # Login to ECR
   aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin $ECR_REPO
   
   # Build and push connector image
   cd connectors
   docker build -t $ECR_REPO:latest .
   docker push $ECR_REPO:latest
   ```

7. **Deploy Producer App**
   ```bash
   kubectl apply -f producer-app-data.yaml
   ```

## Verification

1. **Check Cluster Status**
   ```bash
   kubectl get nodes
   kubectl get pods -n confluent
   ```

2. **Access Control Center**
   ```bash
   kubectl port-forward service/controlcenter 9021:9021
   # Open http://localhost:9021 in your browser
   ```

## Troubleshooting

1. **If kubectl shows "No resources found"**
   - Verify that the EKS cluster is fully provisioned
   - Check that the node group is created and nodes are running
   - Ensure you're in the correct namespace

2. **If pods are not starting**
   - Check pod events: `kubectl describe pod <pod-name>`
   - Check pod logs: `kubectl logs <pod-name>`

3. **If Control Center is not accessible**
   - Verify the port-forward is running
   - Check if the service is running: `kubectl get svc controlcenter` 