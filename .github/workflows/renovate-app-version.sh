#!/bin/bash
set -euo pipefail

process_docker_compose_file() {
  local docker_compose_file=$1
  local app_prefix app_name old_version rest

  IFS='/' read -r app_prefix app_name old_version rest <<< "$docker_compose_file"

  if [[ "$app_prefix" != "apps" || -z "$app_name" || -z "$old_version" || "$rest" != "docker-compose.yml" ]]; then
    echo "Skip non-app docker-compose path: $docker_compose_file"
    return 0
  fi

  local app_version_dir="apps/$app_name/$old_version"

  if [[ ! -f "$docker_compose_file" ]]; then
    echo "No docker-compose.yml found at $docker_compose_file"
    return 0
  fi

  local image_line image
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
    return 0
  fi

  local new_version="${image##*:}"

  if [[ "$new_version" == "$image" || "$new_version" == */* ]]; then
    echo "Image does not contain a docker tag: $image"
    return 0
  fi

  if [[ "$new_version" == "$old_version" ]]; then
    echo "Version directory is already up to date: $old_version"
    return 0
  fi

  local new_app_version_dir="apps/$app_name/$new_version"

  if [[ -e "$new_app_version_dir" ]]; then
    echo "Target version directory already exists: $new_app_version_dir"
    return 1
  fi

  mv "$app_version_dir" "$new_app_version_dir"
}

if [[ "$#" -eq 2 ]]; then
  process_docker_compose_file "apps/$1/$2/docker-compose.yml"
  exit 0
fi

if [[ "$#" -ne 0 ]]; then
  echo "Usage: $0 [app_name old_version]"
  exit 2
fi

updated_files=()
while IFS= read -r file; do
  updated_files+=("$file")
done < <(
  {
    git diff --name-only -- apps
    git diff --cached --name-only -- apps
  } | grep -E '^apps/[^/]+/[^/]+/docker-compose\.yml$' | sort -u || true
)

if [[ "${#updated_files[@]}" -eq 0 ]]; then
  echo "No updated app docker-compose.yml files found."
  exit 0
fi

for file in "${updated_files[@]}"; do
  process_docker_compose_file "$file"
done
