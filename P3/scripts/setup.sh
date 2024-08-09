#!/bin/bash

# Créer un cluster K3d
k3d cluster create myk3dcluster

# Créer un namespace pour Argo CD
kubectl create namespace argocd

# Installer Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Attendre que tous les pods Argo CD soient en état "Running"
echo "En attente des pods Argo CD..."
while true; do
  PENDING_PODS=$(kubectl get pods -n argocd --no-headers | grep -c "Pending")
  RUNNING_PODS=$(kubectl get pods -n argocd --no-headers | grep -c "Running")
  TOTAL_PODS=$(kubectl get pods -n argocd --no-headers | wc -l)

  if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ] && [ "$TOTAL_PODS" -ne 0 ]; then
    break
  fi

  echo "Pods en attente : $PENDING_PODS, Pods en cours d'exécution : $RUNNING_PODS / $TOTAL_PODS"
  sleep 5
done
echo "Tous les pods Argo CD sont en cours d'exécution."

# Attendre que le service argocd-server soit prêt
echo "En attente du service argocd-server..."
while [ -z "$(kubectl get svc argocd-server -n argocd --no-headers | awk '{print $3}')" ]; do
  sleep 5
done
echo "Le service argocd-server est prêt."

# Faire le port forwarding du service Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

echo "Waiting to port forwarding ok ..."
sleep 10

# Afficher le mot de passe Argo CD
echo -en "Mot de passe Argo CD : "
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD
echo "Argo cd interface disponible http://127.0.0.1:8080"

# ArgoCD Authentication
argocd login --insecure --username admin --password $ARGOCD_PASSWORD --grpc-web 127.0.0.1:8080

argocd app sync wil42

kubectl create namespace dev

kubectl apply -f ../confs/deploy.yaml -n argocd

echo "Setup fini"