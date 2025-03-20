#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

VERSION=$1
IMAGE_NAME="fadhiljr/django-admin"

echo "Building Docker image: ${IMAGE_NAME}:${VERSION}"
docker build -t ${IMAGE_NAME}:${VERSION}  ../

echo "Pushing Docker image: ${IMAGE_NAME}:${VERSION}"
docker push ${IMAGE_NAME}:${VERSION}

echo "Build and push complete."
