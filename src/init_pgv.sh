#!/bin/bash
set -euxo pipefail
module load nodejs/16.15.0

datafiles_json=$1
datadir=$2
settings=$3
pgv_dir=$4
build=$5

echo "Checking if PGV instance exists..."
if [[ -d "$pgv_dir" ]]; then
  echo "PGV instance already exists in $pgv_dir"
  echo "Updating local repo..."
  cd "$pgv_dir"
  git pull origin main
else
  echo "Downloading pgv..."
  git clone "https://github.com/mskilab-org/pgv.git" "$pgv_dir"
fi

# Remove extra "/"
datafiles_json=$(echo "$datafiles_json" | tr -s '/')
settings=$(echo "$settings" | tr -s '/')
datadir=$(echo "$datadir" | tr -s '/')
pgv_dir=$(echo "$pgv_dir" | tr -s '/')

echo "Setting up PGV instance with PGVdb data..."

# Coerce paths to absolute paths
datafiles_json_abs=$(realpath "$datafiles_json")
pgv_datafiles_json_abs=$(realpath "$pgv_dir/public/datafiles.json")
settings_abs=$(realpath "$settings")
pgv_settings_json_abs=$(realpath "$pgv_dir/public/settings.json")

if [[ "$datafiles_json_abs" != "$pgv_datafiles_json_abs" ]]; then
    cp -f "$datafiles_json_abs" "$pgv_datafiles_json_abs"
fi

if [[ "$settings_abs" != "$pgv_settings_json_abs" ]]; then
    cp -f "$settings_abs" "$pgv_settings_json_abs"
fi

origin_directory=$datadir
target_directory="$pgv_dir/public/data"

# Create target directory structure if it doesn't exist
mkdir -p "$target_directory"

copy_directory() {
  local origin_dir="$1"
  local target_dir="$2"

  # If the symbolic link at the target directory does not already exist, create it
  if [[ ! -e "$target_dir" ]]; then
    ln -s "$origin_dir" "$target_dir"
  fi
}

# Call the copy_directory function with the origin and target directory paths
copy_directory "$origin_directory" "$target_directory"

echo "Launching PGV..."
cd $pgv_dir

npm install --force

# Check if gene files are available and if not then download
if [ ! -s public/genes/hg19.arrow ]; then
    echo 'Downloading hg19.arrow'
    wget -P public/genes https://mskilab.s3.amazonaws.com/pgv/hg19.arrow
fi
if [ ! -s public/genes/hg19_chr.arrow ]; then
    echo 'Downloading hg19_chr.arrow'
    wget -P public/genes https://mskilab.s3.amazonaws.com/pgv/hg19_chr.arrow
fi
if [ ! -s public/genes/hg38.arrow ]; then
    echo 'Downloading hg38.arrow'
    wget -P public/genes https://mskilab.s3.amazonaws.com/pgv/hg38.arrow
fi
if [ ! -s public/genes/hg38_chr.arrow ]; then
    echo 'Downloading hg38_chr.arrow'
    wget -P public/genes https://mskilab.s3.amazonaws.com/pgv/hg38_chr.arrow
fi

if [ ! -s public/datafiles.json ]; then
    echo 'No datafiles.json was found so using the DEMO data'
    echo "To use your own data, don't forget to update datafiles.json"
    cp -f public/datafiles0.json public/datafiles.json
fi

if [ "$build" = "TRUE" ]; then
    echo "Building PGV..."

    rm -rf ./build
    npm build
else
    echo "Starting PGV in dev server..."
    npm run start
fi
