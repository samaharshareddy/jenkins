#!/bin/bash

set -e

# ---------------------------------------------------------
# Step 2: Navigate to local_downloads
# ---------------------------------------------------------
cd /var/apim/mule-containerize-master-uat/local_downloads || {
    echo "Directory not found"
    exit 1
}
echo "✅ Successfully navigated to local_downloads."

# ---------------------------------------------------------
# Step 3: Move existing files to backup (if any)
# ---------------------------------------------------------
if [ "$(ls -A /var/apim/mule-containerize-master-uat/local_downloads)" ]; then
    mv /var/apim/mule-containerize-master-uat/local_downloads/* \
       /var/apim/api-jars-bkp/ || {
        echo "Failed to move files"
        exit 1
    }
    echo "✅ Successfully moved old files to backup."
else
    echo "ℹ️ No files found in local_downloads. Skipping backup step."
fi

# ---------------------------------------------------------
# Step 4: Navigate to /home/apim
# ---------------------------------------------------------
cd /home/apim || {
    echo "Directory not found"
    exit 1
}
echo "✅ Successfully navigated to /home/apim."

# ---------------------------------------------------------
# Step 5: Ask for JAR file name
# ---------------------------------------------------------
read -p "Enter the .jar file name (with extension): " jar_name

# ---------------------------------------------------------
# Step 6: Move JAR to local_downloads
# ---------------------------------------------------------
if [ -f "$jar_name" ]; then
    mv "$jar_name" /var/apim/mule-containerize-master-uat/local_downloads/
    echo "✅ Successfully moved $jar_name to local_downloads."
else
    echo "❌ File not found: $jar_name"
    exit 1
fi

# ---------------------------------------------------------
# Step 7: Check if only one file exists
# ---------------------------------------------------------
cd /var/apim/mule-containerize-master-uat/local_downloads || exit 1

file_count=$(ls | wc -l)
if [ "$file_count" -ne 1 ]; then
    echo "❌ Error: There should be only one file in local_downloads. Found $file_count files."
    exit 1
fi
echo "✅ Verified only one file exists in local_downloads."

# ---------------------------------------------------------
# Step 8: Go up one directory
# ---------------------------------------------------------
cd ..
echo "✅ Successfully navigated to parent directory."

# ---------------------------------------------------------
# Step 9: Ask for Docker image name
# ---------------------------------------------------------
read -p "Enter Docker image name (without version): " image_name

# ---------------------------------------------------------
# Step 10: Determine next version automatically (v1, v2, ...)
# ---------------------------------------------------------
echo "🔍 Checking latest version for $image_name..."

latest_version=$(docker images --format "{{.Repository}}:{{.Tag}}" \
    | grep "^$image_name:" \
    | awk -F: '{print $2}' \
    | grep -E '^v[0-9]+$' \
    | sort -V \
    | tail -n 1)

if [ -z "$latest_version" ]; then
    next_version="v1"
    echo "ℹ️ No previous version found. Starting with $next_version"
else
    current_num=${latest_version#v}
    next_num=$((current_num + 1))
    next_version="v$next_num"
    echo "✅ Latest version: $latest_version → Next version: $next_version"
fi

final_tag="$image_name:$next_version"

# ---------------------------------------------------------
# Step 11: Build Docker image
# ---------------------------------------------------------
docker build -t "$final_tag" . && \
    echo "✅ Docker image built successfully." || {
    echo "❌ Docker build failed"
    exit 1
}

# ---------------------------------------------------------
# Step 12: Verify image creation
# ---------------------------------------------------------
if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$final_tag"; then
    echo "✅ Verified: Docker image $final_tag exists locally."
else
    echo "❌ Error: Docker image $final_tag not found."
    exit 1
fi

# ---------------------------------------------------------
# Step 13: Tag image for Harbor
# ---------------------------------------------------------
harbor_url="harborrmz.sbiindia.co.in/apim-mule-repo/$image_name:$next_version"

docker tag "$final_tag" "$harbor_url" && \
    echo "✅ Docker image tagged successfully." || {
    echo "❌ Docker tag failed"
    exit 1
}

# ---------------------------------------------------------
# Step 14: Push image to Harbor
# ---------------------------------------------------------
docker push "$harbor_url" && \
    echo "✅ Docker image pushed successfully." || {
    echo "❌ Docker push failed"
    exit 1
}

# Verify image in Harbor
if docker pull "$harbor_url" >/dev/null 2>&1; then
    echo "✅ Verified: Image exists in Harbor at $harbor_url."
else
    echo "❌ Error: Image not found in Harbor."
    exit 1
fi

echo "🎉 Image $final_tag created and pushed successfully! Proceed with deployment."

# ---------------------------------------------------------
# Step 15: Move JAR to backup directory
# ---------------------------------------------------------
if [ -f "/var/apim/mule-containerize-master-uat/local_downloads/$jar_name" ]; then
    mv "/var/apim/mule-containerize-master-uat/local_downloads/$jar_name" \
       /var/apim/api-jars-bkp/ && \
       echo "✅ Successfully moved $jar_name to backup."
else
    echo "ℹ️ $jar_name not found in local_downloads. Skipping backup step."
fi
