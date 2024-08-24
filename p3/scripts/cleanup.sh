#!/bin/bash

# Stop and remove all K3d clusters
echo "Removing K3d clusters..."
k3d cluster delete

# Stop and remove all Docker containers related to Argo CD and K3d
echo "Stopping and removing Docker containers..."
docker ps -a | grep "k3d\|argocd" | awk '{print $1}' | xargs -r docker stop
docker ps -a | grep "k3d\|argocd" | awk '{print $1}' | xargs -r docker rm

# Remove Docker networks created by K3d
echo "Removing Docker networks..."
docker network ls | grep "k3d" | awk '{print $1}' | xargs -r docker network rm

echo "Cleanup complete!"
