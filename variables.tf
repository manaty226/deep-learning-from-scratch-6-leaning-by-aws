variable "aws_region" {
  description = "AWS region in which the SageMaker AI training jobs run."
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Lowercase name used as a prefix for AWS resources."
  type        = string
  default     = "dlfs6-sagemaker"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, digits, or hyphens, and must not start or end with a hyphen."
  }
}

variable "training_jobs" {
  description = "Training jobs to create. Set to [\"ch03\"], [\"ch06\"], or both."
  type        = set(string)
  default     = ["ch03", "ch06"]

  validation {
    condition     = length(setsubtract(var.training_jobs, toset(["ch03", "ch06"]))) == 0
    error_message = "training_jobs may contain only ch03 and ch06."
  }
}

variable "job_name_suffix" {
  description = "Suffix used to create immutable SageMaker job names. Change it to run the jobs again."
  type        = string
  default     = "v1"

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,15}$", var.job_name_suffix))
    error_message = "job_name_suffix must be 1-16 letters, digits, or hyphens."
  }
}

variable "instance_type" {
  description = "SageMaker GPU instance type used by both jobs."
  type        = string
  default     = "ml.g5.xlarge"
}

variable "volume_size_gb" {
  description = "EBS volume size for each training job. The ch06 source bundle contains about 1.1 GB of data."
  type        = number
  default     = 30

  validation {
    condition     = var.volume_size_gb >= 10
    error_message = "volume_size_gb must be at least 10."
  }
}

variable "max_runtime_seconds" {
  description = "Maximum runtime per training job."
  type        = number
  default     = 86400
}

variable "enable_managed_spot_training" {
  description = "Use managed Spot training to reduce compute cost."
  type        = bool
  default     = false
}

variable "max_wait_time_seconds" {
  description = "Maximum total wait time when managed Spot training is enabled."
  type        = number
  default     = 172800
}

variable "ch03_data_path" {
  description = "Path to the ch03 token data inside the SageMaker training container."
  type        = string
  default     = "/opt/ml/code/.data/codebot/tiny_codes.bin"
}

variable "ch03_tokenizer_path" {
  description = "Path to the ch03 tokenizer file inside the SageMaker training container."
  type        = string
  default     = "/opt/ml/code/.data/codebot/merge_rules.pkl"
}

variable "ch06_train_data_path" {
  description = "Path to the ch06 training data inside the SageMaker training container."
  type        = string
  default     = "/opt/ml/code/.data/storybot/tiny_stories_train.bin"
}

variable "ch06_validation_data_path" {
  description = "Path to the ch06 validation data inside the SageMaker training container."
  type        = string
  default     = "/opt/ml/code/.data/storybot/tiny_stories_valid.bin"
}

variable "ch06_tokenizer_path" {
  description = "Path to the ch06 tokenizer file inside the SageMaker training container."
  type        = string
  default     = "/opt/ml/code/.data/storybot/merge_rules.pkl"
}

variable "pytorch_image_tag" {
  description = "AWS Deep Learning Container tag for PyTorch training."
  type        = string
  default     = "2.9.0-gpu-py312-cu130-ubuntu22.04-sagemaker"
}

variable "force_destroy_bucket" {
  description = "Allow terraform destroy to delete the bucket even when it contains model artifacts."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags added to all supported AWS resources."
  type        = map(string)
  default = {
    Project   = "deep-learning-from-scratch-6"
    ManagedBy = "Terraform"
  }
}
