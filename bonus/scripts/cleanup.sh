#!/bin/bash

# Fonction de nettoyage pour arrêter les processus de port forwarding
cleanup_port_forwarding() {
  echo "Arrêt des processus de port forwarding..."
  pkill -f "kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181"
  pkill -f "kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "Processus de port forwarding arrêtés."
}

# Supprimer les namespaces Kubernetes
cleanup_namespaces() {
  echo "Suppression des namespaces Kubernetes..."
  kubectl delete namespace gitlab --ignore-not-found
  kubectl delete namespace argocd --ignore-not-found
  echo "Namespaces Kubernetes supprimés."
}

# Détruire le cluster k3d
destroy_k3d_cluster() {
  echo "Destruction du cluster k3d..."
  k3d cluster delete myk3dbonuscluster
  echo "Cluster k3d détruit."
}

# Exécuter les fonctions de nettoyage
cleanup_port_forwarding
cleanup_namespaces
destroy_k3d_cluster

echo "Nettoyage terminé."
