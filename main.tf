locals {
  upstream_dir = "${path.module}/third_party/deep-learning-from-scratch-6"

  all_jobs = {
    ch03 = {
      script               = "ch03/01_pretrain.py"
      train_data_path      = var.ch03_data_path
      validation_data_path = ""
      tokenizer_path       = var.ch03_tokenizer_path
      model_path           = "/opt/ml/model/model_pretrain.pt"
      loss_plot_path       = "/opt/ml/model/loss_pretrain.png"
      checkpoint_dir       = "/opt/ml/checkpoints"
    }
    ch06 = {
      script               = "ch06/05_pretrain.py"
      train_data_path      = var.ch06_train_data_path
      validation_data_path = var.ch06_validation_data_path
      tokenizer_path       = var.ch06_tokenizer_path
      model_path           = "/opt/ml/model/model_pretrain.pt"
      loss_plot_path       = "/opt/ml/model/loss_val.png"
      checkpoint_dir       = "/opt/ml/checkpoints"
    }
  }

  selected_jobs = {
    for name, config in local.all_jobs : name => config
    if contains(var.training_jobs, name)
  }
}

data "archive_file" "training_source" {
  type        = "tar.gz"
  source_dir  = path.module
  output_path = "${path.module}/.build/source.tar.gz"

  excludes = [
    ".build",
    ".build/**",
    ".git",
    ".git/**",
    ".terraform",
    ".terraform/**",
    ".terraform.lock.hcl",
    "**/.git",
    "**/.git/**",
    "**/__pycache__",
    "**/__pycache__/**",
    "**/*.pyc",
    ".data/**/*.part",
    "*.tfplan",
    "*.tfstate",
    "*.tfstate.*",
    "*.tfvars",
    "*.tfvars.json",
  ]

  lifecycle {
    precondition {
      condition = alltrue([
        fileexists("${local.upstream_dir}/ch03/01_pretrain.py"),
        fileexists("${local.upstream_dir}/ch06/05_pretrain.py"),
        fileexists("${local.upstream_dir}/codebot/tiny_codes.bin"),
        fileexists("${local.upstream_dir}/storybot/model.py"),
      ])
      error_message = "The upstream submodule is missing. Run: git submodule update --init --recursive"
    }
  }
}

resource "random_id" "bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "training" {
  bucket        = "${var.project_name}-${random_id.bucket.hex}"
  force_destroy = var.force_destroy_bucket
}

resource "aws_s3_bucket_public_access_block" "training" {
  bucket = aws_s3_bucket.training.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "training_source" {
  bucket      = aws_s3_bucket.training.id
  key         = "source/${data.archive_file.training_source.output_sha256}/source.tar.gz"
  source      = data.archive_file.training_source.output_path
  source_hash = data.archive_file.training_source.output_sha256

  depends_on = [
    aws_s3_bucket_public_access_block.training,
    aws_s3_bucket_server_side_encryption_configuration.training,
  ]
}

data "aws_sagemaker_prebuilt_ecr_image" "pytorch" {
  repository_name = "pytorch-training"
  image_tag       = var.pytorch_image_tag
}

resource "aws_sagemaker_training_job" "pretrain" {
  for_each = local.selected_jobs

  training_job_name = "${var.project_name}-${each.key}-${var.job_name_suffix}"
  role_arn          = aws_iam_role.sagemaker.arn

  algorithm_specification {
    training_image                       = data.aws_sagemaker_prebuilt_ecr_image.pytorch.registry_path
    training_input_mode                  = "File"
    enable_sagemaker_metrics_time_series = true

    metric_definitions {
      name  = "train:loss"
      regex = "(?:^|[^A-Za-z_])loss[=:][ ]*([0-9.]+)"
    }

    metric_definitions {
      name  = "validation:loss"
      regex = "val_loss[=:][ ]*([0-9.]+)"
    }
  }

  hyper_parameters = {
    sagemaker_program          = "sagemaker/entrypoint.py"
    sagemaker_submit_directory = "s3://${aws_s3_object.training_source.bucket}/${aws_s3_object.training_source.key}"
    sagemaker_region           = var.aws_region
  }

  environment = merge({
    DLFS_TARGET          = each.key
    DLFS_TRAIN_DATA_PATH = each.value.train_data_path
    DLFS_TOKENIZER_PATH  = each.value.tokenizer_path
    DLFS_MODEL_PATH      = each.value.model_path
    DLFS_LOSS_PLOT_PATH  = each.value.loss_plot_path
    DLFS_CHECKPOINT_DIR  = each.value.checkpoint_dir
    MPLBACKEND           = "Agg"
    PYTHONUNBUFFERED     = "1"
    }, each.value.validation_data_path != "" ? {
    DLFS_VALID_DATA_PATH = each.value.validation_data_path
  } : {})

  output_data_config {
    s3_output_path = "s3://${aws_s3_bucket.training.id}/output/${each.key}/"
  }

  checkpoint_config {
    local_path = "/opt/ml/checkpoints"
    s3_uri     = "s3://${aws_s3_bucket.training.id}/checkpoints/${each.key}/"
  }

  resource_config {
    instance_count    = 1
    instance_type     = var.instance_type
    volume_size_in_gb = var.volume_size_gb
  }

  enable_managed_spot_training = var.enable_managed_spot_training

  stopping_condition {
    max_runtime_in_seconds   = var.max_runtime_seconds
    max_wait_time_in_seconds = var.enable_managed_spot_training ? var.max_wait_time_seconds : null
  }

  tags = {
    Chapter        = each.key
    UpstreamScript = each.value.script
  }

  depends_on = [
    aws_iam_role_policy.sagemaker,
    aws_s3_object.training_source,
  ]
}
