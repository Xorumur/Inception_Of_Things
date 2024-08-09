#!/bin/bash

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


# Créer un cluster K3d avec les ports mappés
k3d cluster create myk3dbonuscluster

echo "Installation de Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "Installation de Helm terminée"

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

sleep 10

# ArgoCD Authentication
argocd login --insecure --username admin --password $ARGOCD_PASSWORD --grpc-web 127.0.0.1:8080

argocd app sync wil42

kubectl create namespace dev

kubectl apply -f ../confs/deploy.yaml -n argocd

kubectl create namespace gitlab

echo "Configuration de l'instance gitlab"
helm repo add gitlab https://charts.gitlab.io/
helm repo update
helm upgrade --install gitlab gitlab/gitlab --namespace gitlab -f ../confs/gitlab_conf.yaml

# Fonction pour vérifier l'état des pods

wait_for_pods gitlab

echo -n "Mot de passe GitLab : "
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode




sudo fuser -k 8081/tcp
sudo kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181 > /dev/null 2>&1 &




echo "Setup terminé"
