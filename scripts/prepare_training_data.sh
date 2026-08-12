#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPOSITORY_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
UPSTREAM_ROOT="${REPOSITORY_ROOT}/third_party/deep-learning-from-scratch-6"
DATA_ROOT="${REPOSITORY_ROOT}/.data"
TARGET=${1:-all}

copy_data() {
  local source=$1
  local destination=$2

  if [[ -f "${destination}" ]]; then
    echo "Using existing file: ${destination}"
    return
  fi

  mkdir -p "$(dirname "${destination}")"
  cp "${source}" "${destination}"
  echo "Prepared: ${destination}"
}

download_data() {
  local url=$1
  local destination=$2

  if [[ -f "${destination}" ]]; then
    echo "Using existing file: ${destination}"
    return
  fi

  mkdir -p "$(dirname "${destination}")"
  echo "Downloading: ${url}"
  curl --fail --location --retry 5 --retry-delay 2 \
    --output "${destination}.part" "${url}"
  mv "${destination}.part" "${destination}"
  echo "Downloaded: ${destination}"
}

prepare_ch03() {
  copy_data \
    "${UPSTREAM_ROOT}/codebot/tiny_codes.bin" \
    "${DATA_ROOT}/codebot/tiny_codes.bin"
  copy_data \
    "${UPSTREAM_ROOT}/codebot/merge_rules.pkl" \
    "${DATA_ROOT}/codebot/merge_rules.pkl"
}

prepare_ch06() {
  local base_url="https://huggingface.co/datasets/koki0702/zero-llm-data/resolve/main/storybot"

  download_data \
    "${base_url}/tiny_stories_train.bin" \
    "${DATA_ROOT}/storybot/tiny_stories_train.bin"
  download_data \
    "${base_url}/tiny_stories_valid.bin" \
    "${DATA_ROOT}/storybot/tiny_stories_valid.bin"
  download_data \
    "${base_url}/merge_rules.pkl" \
    "${DATA_ROOT}/storybot/merge_rules.pkl"
}

git -C "${REPOSITORY_ROOT}" submodule update --init --recursive

case "${TARGET}" in
  ch03)
    prepare_ch03
    ;;
  ch06)
    prepare_ch06
    ;;
  all)
    prepare_ch03
    prepare_ch06
    ;;
  *)
    echo "Usage: $0 [ch03|ch06|all]" >&2
    exit 2
    ;;
esac

echo "Training data is ready under ${DATA_ROOT}"
