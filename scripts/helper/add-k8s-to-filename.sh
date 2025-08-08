#!/bin/bash

# Find all .yaml files recursively
find . -type f -name "*.yaml" | while read -r file; do
    filename=$(basename "$file")
    
    # Skip kustomize.yaml
    if [[ "$filename" == "kustomize.yaml" ]]; then
        continue
    fi

    # Construct new filename
    newfile="${file%.yaml}.k8s.yaml"

    # Rename file
    mv "$file" "$newfile"

    echo "Renamed: $file -> $newfile"
done