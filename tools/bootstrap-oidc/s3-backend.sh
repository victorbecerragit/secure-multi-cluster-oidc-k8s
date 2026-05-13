#!/usr/bin/env bash
set -euo pipefail

BUCKET_NAME="secure-mc-tfstate-200227355781"
AWS_REGION="us-east-1"
STATE_PREFIX="environments/dev/terraform.tfstate"

bucket_exists() {
  aws s3api head-bucket --bucket "$BUCKET_NAME" >/dev/null 2>&1
}

create_bucket() {
  echo "Creating S3 state bucket: $BUCKET_NAME"

  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" >/dev/null
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration "LocationConstraint=$AWS_REGION" >/dev/null
  fi
}

configure_bucket() {
  echo "Configuring bucket versioning"
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled >/dev/null

  echo "Configuring bucket encryption"
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null

  echo "Blocking public access"
  aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" >/dev/null
}

if bucket_exists; then
  echo "S3 state bucket already exists: $BUCKET_NAME"
else
  create_bucket
fi

configure_bucket

cat <<EOF
S3 backend bucket is ready.

Backend settings:
  bucket       = "$BUCKET_NAME"
  key          = "$STATE_PREFIX"
  region       = "$AWS_REGION"
  encrypt      = true
  use_lockfile = true
EOF
