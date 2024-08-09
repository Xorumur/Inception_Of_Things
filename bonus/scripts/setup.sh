#!/bin/bash

set -e

# Fonction pour libérer le port 8081 si utilisé
free_port_8081() {
  local PORT=8081
  if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo "Le port $PORT est actuellement utilisé. Libération en cours..."
    fuser -k 8081/tcp
    echo "Port $PORT libéré."
  else
    echo "Le port $PORT est disponible."
  fi
}

# Libérer le port 8081 si nécessaire
free_port_8081

# Fonction de nettoyage pour arrêter les processus de port forwarding
cleanup() {
  echo "Nettoyage : arrêt des processus de port forwarding"
  # Trouver les processus de port forwarding et les terminer
  pkill -f "kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181"
  pkill -f "kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "Nettoyage terminé"
}

# Définir les traps pour les signaux d'arrêt
trap cleanup SIGINT SIGTERM

k3d cluster create myk3dbonuscluster

echo "Installation du package manage kubernetes Helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
echo "Installation de Helm fini"

echo "Création du namespace gitlab"
kubectl create namespace gitlab

echo "Configuration de l'instance gitlab"

helm repo add gitlab https://charts.gitlab.io/

helm repo update

echo "Configuration de l'instance gitlab"

helm upgrade --install gitlab gitlab/gitlab --namespace gitlab -f ../confs/gitlab_conf.yaml

NAMESPACE="gitlab"

# Fonction pour vérifier l'état des pods
check_pods() {
  kubectl get pods -n $NAMESPACE | grep -v 'Running\|Completed\|NAME' | wc -l
}

# Attendre que tous les pods soient en état 'Running' ou 'Completed'
echo "Attente que tous les pods soient en état 'Running' ou 'Completed'..."
while [ $(check_pods) -ne 0 ]; do
  echo "Des pods sont encore en cours d'initialisation ou en échec. Attente..."
  sleep 10
done

echo "Tous les pods sont en état 'Running' ou 'Completed'."


echo -n "Mot de passe GitLab : ";
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -ojsonpath='{.data.password}' | base64 --decode ; 


sudo kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181 &
echo "Waiting to port forwarding ok ..."
sleep 10

while true ; do 
    PORT_FORWARD=$(ps aux | grep "kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181" | grep -v grep | wc -l)
    if [ "$PORT_FORWARD" -eq 0 ] ; then
        sudo kubectl port-forward -n gitlab svc/gitlab-webservice-default 8081:8181 &
        echo "New attempts of port forward"
        sleep 10
    else
        break
    fi
done


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
 kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &

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