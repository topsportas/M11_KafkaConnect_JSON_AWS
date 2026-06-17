variable "AWS_REGION" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-west-1"
}

variable "KAFKA_TOPICS" {
  description = "Comma-separated list of Kafka topics"
  type        = string
  default     = "expedia"
}

variable "S3_TOPICS_DIR" {
  description = "Directory in S3 where topic data is stored"
  type        = string
  default     = "topics"
}

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