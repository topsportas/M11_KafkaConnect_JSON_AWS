# KafkaConnect [json]

## Prerequisites

Before proceeding, ensure you have the following tools installed:

- Rancher Desktop – Required for running Kubernetes locally (alternative to Docker Desktop). Please keep it running.
- Java – Needed for running Java applications and scripts. Recommended Java version - openjdk 11.
- Python 3 – Needed for running Python-based applications and scripts. Recommended Python version - 3.13.(latest version).
- AWS CLI – Used to interact with AWS services and manage resources.
- Terraform – Infrastructure as Code (IaC) tool for provisioning AWS resources.
- Spark – Unified analytics engine for large-scale data processing; required to run Spark jobs using spark-submit.
- dos2unix - command-line tool that converts Windows-style endings (CRLF) to Unix (LF).
- eksctl – Command-line tool for creating and managing Kubernetes clusters on AWS EKS.

📘 Follow the full setup instructions for [Windows environment setup](./setup-windows.md)<br>
🍎 Follow the full setup instructions for [MacOS environment setup](./setup-macos.md)<br>
🐧 Follow the full setup instructions for [Ubuntu 24.10 environment setup](./setup-ubuntu.md)

📌 **Important Guidelines**
Please read the instructions carefully before proceeding. Follow these guidelines to avoid mistakes:

- If you see `<SOME_TEXT_HERE>`, you need to **replace this text and the brackets** with the appropriate value as described in the instructions.
- Follow the steps in order to ensure proper setup.
- Pay attention to **bolded notes**, warnings, or important highlights throughout the document.
- Clean Up AWS Resources Before Proceeding. Since you are using a **free-tier** AWS account, it’s crucial to clean up any leftover resources from previous lessons or deployments before proceeding. Free-tier accounts have strict resource quotas, and exceeding these limits may cause deployment failures.

## Prerequisites
- An active AWS account.
- Appropriate IAM permissions to create users and generate access keys (administrator access is recommended for initial setup).

## 1. AWS CLI Setup

### Log in to AWS Management Console
- Open your web browser and navigate to the [AWS Management Console](https://aws.amazon.com/console/).
- Log in using your AWS account credentials.

###  Create a New IAM User
- In the AWS Console, locate the search bar and type **IAM**, then select **IAM** from the list.
- In the left-hand navigation pane, click **Users**.

#### Create a User and Add to a Group
1. Click **Add user**.
2. Enter a  **User name**.
3. Under **Select AWS access type**, check **Programmatic access**.
4. Click **Next: Permissions**.
5. Choose **Add user to group**.
   - If a suitable group exists, select it.
   - Otherwise, create a new group by clicking **Create group**, enter a  **User group name** then assign the **AdministratorAccess** policy to the group.
6. Click **Next**.
7. Click **Create user**.

###  Retrieve Your Access Keys

- **Important:** Copy and store the **SecretAccessKey** and **AccessKeyId** immediately.
The next time you will run the command the new access key will be generated, and the old one will be deleted.
```bash
aws iam create-access-key --user-name <your-user-name>
```

### Configure the AWS CLI
- Open a terminal and run the following command:

```bash
aws configure
``` 
When prompted, enter the following details:

- **AWS Access Key ID**: Your obtained `AccessKeyId`.
- **AWS Secret Access Key**: Your obtained `SecretAccessKey`.
- **Default region name**: `us-west-1`
- **Default output format**: `json`


## 2. Update Terraform Configuration

Navigate into folder `terraform`. Modify `variables.tf` and replace placeholders with your actual values.

- **Edit the default value for AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY with your actual values  in `variables.tf` :**

```hcl
variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key ID for S3 access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS secret access key for S3 access"
  type        = string
  sensitive   = true
  default     = ""
} 
```

## 3. Deploy Infrastructure with Terraform

To start the deployment using Terraform scripts, you need to navigate to the `terraform` folder.

```bash
cd terraform/
```

- Run the following Terraform commands:

    ```bash
    terraform init
    ```
    
    ```bash
    terraform plan -out terraform.plan
    ```
    
    ```bash
    terraform apply terraform.plan
    ```

- To see the EKS cluster name that was created by terraform (`<eks_cluster_name>`) run the command:

    ```bash
    terraform output eks_cluster_name
    ```




## 4. Verify Resource Deployment in AWS

After Terraform completes, verify that resources were created:

1. **Go to the [AWS Console](https://console.aws.amazon.com/)**  
2. Navigate to **EKS** → **Clusters** → **Find `<eks_cluster_name>`**  
3. Check that the resources (EKS Cluster, S3 Bucket, etc.) are created.  

- Alternatively, check via CLI:

    ```bash
    aws eks describe-cluster --name <eks_cluster_name> --region <aws_region>
    ```





## 5. Configure kubectl for EKS

1. Get the EKS cluster name:

    ```bash
    terraform output eks_cluster_name
    ```

2. Update kubeconfig for the EKS cluster:

    ```bash
    aws eks update-kubeconfig --name <eks_cluster_name> --region <region>
    ```

3. Create IAM Service Account


- Retrieve the **aws-account-id**:

    ```bash
    aws sts get-caller-identity --query "Account" --output text
    ```

- Create an IAM service account for Kafka Connect with S3 access:

    ```bash
    eksctl create iamserviceaccount --name kafka --namespace default --cluster <eks_cluster_name> --attach-policy-arn arn:aws:iam::<aws-account-id>:policy/S3SparkAccessPolicy --approve --override-existing-serviceaccounts
    ``` 
 
3. Create kubernetes confluent namespace:

    ```bash
    kubectl create namespace confluent
    ``` 

4. Switch to the project kubernetes namespace:

    ```bash
    kubectl config set-context --current --namespace confluent
    ```

5. Install Confluent for Kubernetes

- Add the Confluent for Kubernetes Helm repository:

    ```bash
    helm repo add confluentinc https://packages.confluent.io/helm
    helm repo update
    ```

- Install Confluent for Kubernetes:

    ```bash
    helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes
    ```



## 5. Configure and Use Amazon Elastic Container Registry (ECR)
Create a new ECR repository in AWS. This repository will be used to store the Docker image for your Spark application.

### Create an ECR Repository

- To create a new ECR repository, run the following command:

    ```bash
    aws ecr create-repository --repository-name aws-connector
    ```

### Authenticate Docker to ECR
To authenticate Docker to your ECR registry, run the following commands:

1. Retrieve the authentication password

    ```bash
    $password = aws ecr get-login-password --region <region>
    ```

2. Retrieve the **aws-account-id**

    ```bash
    aws sts get-caller-identity --query "Account" --output text
    ```

3. Authenticate Docker to ECR

    ```bash
    docker login --username AWS --password $password <aws-account-id>.dkr.ecr.<region>.amazonaws.com
    ```


## 6. Build and push Docker image:

```bash
cd connectors
```
1. ⚠️ To build the Docker image, choose the correct command based on your CPU architecture: 

    <details>
    <summary><code>Linux</code>, <code>Windows</code>, <code>&lt;Intel-based macOS&gt;</code> (<i>click to expand</i>)</summary>
    
    ```bash
    docker build -t m11_kafkaconnect_image .
    ```
    
    </details>
    <details>
    <summary><code>macOS</code> with <code>M1/M2/M3</code> <code>&lt;ARM-based&gt;</code>  (<i>click to expand</i>)</summary>
    
    ```bash
    docker build --platform linux/amd64 -t m11_kafkaconnect_image .
    ```
    </details>

2. Tag Docker Image:

    ```bash
    docker tag m11_kafkaconnect_image:latest <aws-account-id>.dkr.ecr.<region>.amazonaws.com/aws-connector:latest
    ```

3. Push Docker Image to ECR:

    ```bash
    docker push <aws-account-id>.dkr.ecr.<region>.amazonaws.com/aws-connector:latest
    ```   

4. Verify Image in ECR:

    ```bash
    aws ecr describe-images --repository-name aws-connector --region <region> --query 'imageDetails[?imageTags[0]==`latest`]' --output table
    ```  



## 6.  Install Confluent Platform

- Go into `root` folder. Modify the file `confluent-platform.yaml` and replace the placeholder with actual value:

    ```yaml
    image:
    application: <aws-account-id>.dkr.ecr.<region>.amazonaws.com/aws-connector:latest
    init: confluentinc/confluent-init-container:2.10.0
  dependencies:
    ```

- Install all Confluent Platform components:

    ```bash
    kubectl apply -f confluent-platform.yaml
    ```

- Install a sample producer app and topic:

    ```bash
    kubectl apply -f producer-app-data.yaml
    ```

- Installs the AWS EBS CSI driver addon to the EKS cluster.

    ```bash
    eksctl create addon  --name aws-ebs-csi-driver --cluster <eks_cluster_name> --region <region> --force
    ```

- Check that everything is deployed (all pods should be in the `Running` state and have a ready status of `1/1`):
It will take approximately **15–20 minutes** to set up all resources.

    ```bash
    kubectl get pods -o wide 
    ```

### View Control Center

- Set up port forwarding to Control Center web UI from local machine:

    <details>
    <summary><code>Linux</code>, <code>MacOS</code> (<i>click to expand</i>)</summary>

    ```bash
    kubectl port-forward controlcenter-0 9021:9021 &>/dev/null &
    ```

    </details>
    <details>
    <summary><code>Windows - [powershell]</code></code>  (<i>click to expand</i>)</summary>

    ```bash
    Start-Process powershell -WindowStyle Hidden -ArgumentList 'kubectl port-forward controlcenter-0 9021:9021 *> $null'
    ```

    </details>

- Browse to Control Center: [http://localhost:9021](http://localhost:9021)

## 7. Create a kafka topic

The topic should have at least 3 partitions. Name the new topic: `expedia`.

- Create a connection for kafka:

    <details>
    <summary><code>Linux</code>, <code>MacOS</code> (<i>click to expand</i>)</summary>

    ```bash
    kubectl port-forward connect-0 8083:8083 &>/dev/null &
    ```

    </details>
    <details>
    <summary><code>Windows - [powershell]</code></code>  (<i>click to expand</i>)</summary>

    ```bash
    Start-Process powershell -WindowStyle Hidden -ArgumentList 'kubectl port-forward connect-0 8083:8083 *> $null'
    ```

    </details>

- execute below command to create Kafka topic with a name `expedia`

    ```bash
    kubectl exec kafka-0 -c kafka -- bash -c "/usr/bin/kafka-topics --create --topic expedia --replication-factor 3 --partitions 3 --bootstrap-server kafka:9092"
    ```

## 8. Upload the data files into S3 Bucket

1. Log in to [AWS Management Console](https://aws.amazon.com/console/)
2. Go to S3 => Your Bucket Name
3. You should see the upload button
5. Upload the `data` files here.
6. The folder structure should be like:
```bash
    <YOUR_BUCKET_NAME_WHERE_IS_TOPIC_LOCATED>
    └── topics
        └── <TOPIC_NAME>
            ├── partition=0
            │   └── example+0+0000000000.avro
            ├── partition=1
            │   └── example+1+0000000000.avro
            └── partition=2
                └── example+2+0000000000.avro
```


## 9. Upload the connector file through the API

- go into folder `terraform`, and run a command depends on your OS:

    <details>
    <summary><code>Linux</code>, <code>MacOS</code> (<i>click to expand</i>)</summary>

    ```bash
    curl -s -X POST -H "Content-Type:application/json" --data @aws-source-cc.json http://localhost:8083/connectors
    ```

    </details>
    <details>
    <summary><code>Windows - [powershell]</code>  (<i>click to expand</i>)</summary>

    ```bash
    Remove-item alias:curl
    ```

    then:

    ```bash
    curl -s -X POST -H "Content-Type:application/json" --data @aws-source-cc.json http://localhost:8083/connectors
    ```

    </details>

## 10. Verify the messages in Kafka

- Browse to Control Center: [http://localhost:9021](http://localhost:9021)
- Go into Cluster => Topics
- Choose your topic name
- In the `messages` tab you should be able to see incoming messages

## 11. Destroy Infrastructure (Required Step)

After completing all steps, **destroy the infrastructure** to clean up all deployed resources.

⚠️ **Warning:** This action is **irreversible**. Running the command below will **delete all infrastructure components** created in previous steps.

To remove all deployed resources, run:

1. Clean Kubernetes Resources run from the git `root` folder:

    ```bash
    kubectl delete -f producer-app-data.yaml
    ```
    
    ```bash
    kubectl delete -f confluent-platform.yaml
    ```
    
    ```bash
    helm uninstall confluent-operator
    ```
    
    ```bash
    kubectl delete namespace confluent
    ```


2. Deatch  the IAM policy and service account:
- Identify entities attached to the policy:

  ```bash
  aws iam list-entities-for-policy --policy-arn arn:aws:iam::<aws-account-id>:policy/S3SparkAccessPolicy
  ```

- Detach the policy from the entity listed in the previous step.

  ```bash
  aws iam detach-role-policy --role-name <RoleName> --policy-arn arn:aws:iam::<aws-account-id>:policy/S3SparkAccessPolicy
  ```

3. Delete ECR repository
 
    ```bash
    aws ecr batch-delete-image --repository-name m11_kafkaconnect_image --image-ids imageTag=latest
    ```

    ```bash
    aws ecr delete-repository --repository-name aws-connector
    ```

4. Remove  AWS deployed resources, run from the `terraform` folder:

    ```bash
    terraform destroy
    ```