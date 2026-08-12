# 『ゼロから作る Deep Learning ❻』を SageMaker AI で学習する

オライリー・ジャパンのサポートコードにある次の 2 本を、AWS SageMaker AI Training Job で実行する Terraform 構成です。

- `ch03/01_pretrain.py`（CodeBot）
- `ch06/05_pretrain.py`（StoryBot）

上流リポジトリは `third_party/deep-learning-from-scratch-6` に Git submodule として固定しています。`sagemaker/entrypoint.py` は上流スクリプトを変更せずに実行するラッパーです。一時ディレクトリに上流コードと、Terraformから渡されたデータファイルへのシンボリックリンクを配置し、上流スクリプトをそのまま起動します。

## 作成されるもの

- 学習コードとローカル準備済みデータをまとめた source archive
- source archive、チェックポイント、モデル成果物用の暗号化 S3 バケット
- 最小権限の SageMaker 実行ロール
- AWS 公式 PyTorch GPU コンテナを使う ch03/ch06 の Training Job
- CloudWatch へ送る train/validation loss のメトリクス定義

`scripts/prepare_training_data.sh` が必要な `.bin` / `.pkl` をローカルの `.data/` に集約します。ch03 のファイルは submodule からコピーし、ch06 の約 1.1 GiB のデータは Hugging Face からダウンロードします。Terraform は `.data/` とコードを同じ `source.tar.gz` にまとめて S3 にアップロードするため、Training Job 自体はデータ取得のためのインターネット接続を必要としません。

## 前提条件

- Terraform 1.5 以上
- `curl` と、データおよび source archive 用の十分なローカル空き容量
- AWS CLI で利用する認証情報を設定済み
- SageMaker、IAM、S3 を作成でき、`iam:PassRole` を実行できる権限
- 対象リージョンで `ml.g5.xlarge` の SageMaker Training quota が利用可能

## 実行

```bash
git clone --recurse-submodules https://github.com/manaty226/deep-learning-from-scratch-6-leaning-by-aws.git
cd deep-learning-from-scratch-6-leaning-by-aws

# すでに clone 済みの場合だけ必要
git submodule update --init --recursive

cp terraform.tfvars.example terraform.tfvars

# ch03/ch06 の全データをローカルへ準備
bash scripts/prepare_training_data.sh all

terraform init
terraform plan
terraform apply
```

準備対象は個別にも指定できます。

```bash
bash scripts/prepare_training_data.sh ch03
bash scripts/prepare_training_data.sh ch06
```

`.data/` と `.build/source.tar.gz` は Git 管理対象外です。`terraform plan` 時に source archive が生成され、`terraform apply` 時に同じ archive が S3 へアップロードされます。ch06 を含める場合は、ローカルデータと archive の両方を保持できる空き容量を確保してください。

## 学習ファイルのパス

学習スクリプトへ渡すパスはTerraform変数で指定します。既定値はsource archiveが展開される `/opt/ml/code/.data` 配下です。

```hcl
ch03_data_path      = "/opt/ml/code/.data/codebot/tiny_codes.bin"
ch03_tokenizer_path = "/opt/ml/code/.data/codebot/merge_rules.pkl"

ch06_train_data_path      = "/opt/ml/code/.data/storybot/tiny_stories_train.bin"
ch06_validation_data_path = "/opt/ml/code/.data/storybot/tiny_stories_valid.bin"
ch06_tokenizer_path       = "/opt/ml/code/.data/storybot/merge_rules.pkl"
```

Terraformはこれらを `DLFS_TRAIN_DATA_PATH`、`DLFS_VALID_DATA_PATH`、`DLFS_TOKENIZER_PATH` としてTraining Jobへ渡します。ラッパーは受け取ったパスへのシンボリックリンクを、上流コードが期待する `codebot/` または `storybot/` 配下に作成します。

`terraform apply` は既定で両方の Training Job を送信するため、GPU 利用料金が発生します。まずch03だけを実行する場合は `terraform.tfvars` を次のようにします。

```hcl
training_jobs = ["ch03"]
job_name_suffix = "ch03-v1"
```

この場合は `bash scripts/prepare_training_data.sh ch03` だけで実行できます。

ch06だけを実行する場合は次の設定を使えます。事前にローカルへ約 1.1 GiB のデータをダウンロードします。

```hcl
training_jobs = ["ch06"]
job_name_suffix = "ch06-v1"
```

```bash
bash scripts/prepare_training_data.sh ch06
```

上流コードをそのまま実行するため、反復回数も上流の固定値（ch03は `20000`、ch06は `40000`）を使用します。

## 状態とログの確認

```bash
aws sagemaker describe-training-job \
  --training-job-name dlfs6-sagemaker-ch03-v1 \
  --query '{Status:TrainingJobStatus,Reason:FailureReason,Model:ModelArtifacts.S3ModelArtifacts}'

aws logs tail /aws/sagemaker/TrainingJobs --follow
```

正常終了すると、`terraform output model_output_prefixes` で示す S3 prefix 配下に `model.tar.gz` が作成されます。中には `model_pretrain.pt` と loss グラフが入り、ch06 では該当する中間 checkpoint も含まれます。

Training Job 名は SageMaker 上で再利用できません。もう一度学習するときは `job_name_suffix` を `v2` などに変更してください。

## 削除

成果物を誤って消さないよう、S3 バケットの `force_destroy` は既定で無効です。成果物を退避したうえでバケットも含めて削除する場合は、次を設定してから destroy します。

```hcl
force_destroy_bucket = true
```

```bash
terraform apply
terraform destroy
```

## 主な設定

| 変数 | 既定値 | 説明 |
|---|---:|---|
| `aws_region` | `ap-northeast-1` | 実行リージョン |
| `training_jobs` | `ch03`, `ch06` | 作成するジョブ |
| `instance_type` | `ml.g5.xlarge` | GPU インスタンス |
| `ch03_data_path` | `/opt/ml/code/.data/codebot/tiny_codes.bin` | ch03 学習データのコンテナ内パス |
| `ch06_train_data_path` | `/opt/ml/code/.data/storybot/tiny_stories_train.bin` | ch06 学習データのコンテナ内パス |
| `enable_managed_spot_training` | `false` | Managed Spot Training の使用 |
| `job_name_suffix` | `v1` | 再実行時に変更する一意な suffix |

詳細は [variables.tf](./variables.tf) と [terraform.tfvars.example](./terraform.tfvars.example) を参照してください。
