#!/bin/bash

set -e

# Libérer les ports si nécessaire
free_port() {
  local PORT=$1
  if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null; then
    echo "Le port $PORT est actuellement utilisé. Libération en cours..."
    fuser -k $PORT/tcp
    echo "Port $PORT libéré."
  else
    echo "Le port $PORT est disponible."
  fi
}

free_port 8081
free_port 8080

# Fonction de nettoyage pour arrêter les processus de port forwarding
cleanup() {
  echo "Nettoyage : arrêt des processus de port forwarding"
  pkill -f "kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181"
  pkill -f "kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "Nettoyage terminé"
}

# Définir les traps pour les signaux d'arrêt
trap cleanup SIGINT SIGTERM EXIT

# Créer un cluster K3d avec les ports mappés
k3d cluster create myk3dbonuscluster -p "8081:8181@loadbalancer" -p "8080:443@loadbalancer"

echo "Installation de Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "Installation de Helm terminée"

echo "Création du namespace gitlab et argocd"
kubectl create namespace gitlab
kubectl create namespace argocd

echo "Configuration de l'instance gitlab"
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm upgrade --install gitlab gitlab/gitlab --namespace gitlab -f ../confs/gitlab_conf.yaml

# Fonction pour vérifier l'état des pods
check_pods() {
  local NAMESPACE=$1
  kubectl get pods -n $NAMESPACE | grep -v 'Running\|Completed\|NAME' | wc -l
}

# Attendre que tous les pods soient en état 'Running' ou 'Completed'
wait_for_pods() {
  local NAMESPACE=$1
  echo "Attente que tous les pods dans le namespace $NAMESPACE soient en état 'Running' ou 'Completed'..."
  while [ $(check_pods $NAMESPACE) -ne 0 ]; do
    echo "Des pods dans le namespace $NAMESPACE sont encore en cours d'initialisation ou en échec. Attente..."
    sleep 10
  done
  echo "Tous les pods dans le namespace $NAMESPACE sont en état 'Running' ou 'Completed'."
}

wait_for_pods gitlab

echo -n "Mot de passe GitLab : "
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode
echo

kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181 &
echo "Waiting for GitLab port forwarding to be ready..."
sleep 10

echo "Installation d'Argo CD"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

wait_for_pods argocd

echo "En attente du service argocd-server..."
while [ -z "$(kubectl get svc argocd-server -n argocd --no-headers | awk '{print $3}')" ]; do
  sleep 5
done
echo "Le service argocd-server est prêt."

kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
echo "Waiting for Argo CD port forwarding to be ready..."
sleep 10

echo -en "Mot de passe Argo CD : "
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo $ARGOCD_PASSWORD
echo "Argo CD interface disponible à http://127.0.0.1:8080"
#argocd login --insecure --username admin --password $ARGOCD_PASSWORD --grpc-web 127.0.0.1:8080
# argocd app sync wil42

kubectl create namespace dev
kubectl apply -f ../confs/deploy.yaml -n argocd

echo "Setup terminé"
