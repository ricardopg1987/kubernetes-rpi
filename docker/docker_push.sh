#!/bin/bash
set -e  # Exit script on command failure

# Check for required environment variables
if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
  echo "Error: DOCKER_USERNAME and DOCKER_PASSWORD must be set."
  exit 1
fi

# Authenticate Docker
echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin

# Build and push the image
IMAGE_NAME="my-repo/my-image"
TAG="latest"

echo "Building Docker image..."
docker build -t "$IMAGE_NAME:$TAG" .

echo "Pushing Docker image..."
docker push "$IMAGE_NAME:$TAG"

echo "Docker image pushed successfully!"
