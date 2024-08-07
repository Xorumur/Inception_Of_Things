#!/bin/bash

set -e  # Arrête le script en cas d'erreur

echo "Mise à jour des paquets..."
sudo apt-get update

echo "Installation des dépendances nécessaires..."
sudo apt-get install -y curl

# Mettre les bons droits sur kubectl pour éviter de devoir sudo
export K3S_KUBECONFIG_MODE="644"

# Préciser le mode serveur pour l'installation de K3s
export INSTALL_K3S_EXEC="server --node-ip=192.168.56.110"

echo "Installation de K3s..."
sudo curl -sfL https://get.k3s.io | sh -

# Attendre que le token soit disponible
TOKEN="/var/lib/rancher/k3s/server/node-token"
while [ ! -f "$TOKEN" ]; do
    echo "En attente du token K3s..."
    sleep 2
done

# Copie du token K3s pour l'authentification des travailleurs
echo "Copie du token K3s dans le dossier partagé..."
sudo cp $TOKEN /vagrant/token

# Copie du fichier kubeconfig pour l'accès depuis l'hôte
KUBECONFIG="/etc/rancher/k3s/k3s.yaml"
echo "Copie du fichier kubeconfig dans le dossier partagé..."
sudo cp $KUBECONFIG /vagrant/k3s.yaml

echo "alias k='kubectl'" >> /home/vagrant/.bashrc


sudo kubectl apply -f /vagrant/confs/app1/app1-deployment.yaml
sudo kubectl apply -f /vagrant/confs/app2/app2-deployment.yaml
sudo kubectl apply -f /vagrant/confs/app3/app3-deployment.yaml
sudo kubectl apply -f /vagrant/confs/services.yaml
sudo kubectl apply -f /vagrant/confs/ingress.yaml

echo "192.168.56.110 app1.com" >> /etc/hosts
echo "192.168.56.110 app2.com" >> /etc/hosts
echo "192.168.56.110 app3.com" >> /etc/hosts

echo "Installation du serveur K3s terminée avec succès."
