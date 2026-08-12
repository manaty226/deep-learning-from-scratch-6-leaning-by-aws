output "artifact_bucket" {
  description = "S3 bucket containing source bundles, checkpoints, and model artifacts."
  value       = aws_s3_bucket.training.id
}

output "training_job_names" {
  description = "Created SageMaker AI training job names."
  value = {
    for name, job in aws_sagemaker_training_job.pretrain : name => job.training_job_name
  }
}

output "training_job_arns" {
  description = "Created SageMaker AI training job ARNs."
  value = {
    for name, job in aws_sagemaker_training_job.pretrain : name => job.arn
  }
}

output "model_output_prefixes" {
  description = "S3 prefixes under which SageMaker writes model.tar.gz."
  value = {
    for name in keys(local.selected_jobs) : name => "s3://${aws_s3_bucket.training.id}/output/${name}/"
  }
}
