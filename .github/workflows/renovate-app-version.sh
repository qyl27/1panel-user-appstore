#!/bin/bash
set -euo pipefail

app_name=$1
old_version=$2

app_version_dir="apps/$app_name/$old_version"
docker_compose_file="$app_version_dir/docker-compose.yml"

if [[ ! -f "$docker_compose_file" ]]; then
  echo "No docker-compose.yml found at $docker_compose_file"
  exit 0
fi

image_line=$(grep -m 1 -E '^[[:space:]]*image:[[:space:]]*' "$docker_compose_file" || true)
image="${image_line#*:}"
image="${image#"${image%%[![:space:]]*}"}"
image="${image%"${image##*[![:space:]]}"}"
image="${image#\"}"
image="${image%\"}"
image="${image#\'}"
image="${image%\'}"

if [[ -z "$image" || "$image" == *@* ]]; then
  echo "No tag-based image found in $docker_compose_file"
  exit 0
fi

new_version="${image##*:}"

if [[ "$new_version" == "$image" || "$new_version" == */* ]]; then
  echo "Image does not contain a docker tag: $image"
  exit 0
fi

if [[ "$new_version" == "$old_version" ]]; then
  echo "Version directory is already up to date: $old_version"
  exit 0
fi

new_app_version_dir="apps/$app_name/$new_version"

if [[ -e "$new_app_version_dir" ]]; then
  echo "Target version directory already exists: $new_app_version_dir"
  exit 1
fi

git mv "$app_version_dir" "$new_app_version_dir"
