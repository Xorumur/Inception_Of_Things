#!/bin/bash

set -e  # Arrête le script en cas d'erreur

echo "Mise à jour des paquets..."
sudo apt-get update

echo "Installation des dépendances nécessaires..."
sudo apt-get install -y curl

# Définir l'adresse du serveur et le chemin vers le token
SERVER_IP="192.168.56.110"
TOKEN_FILE="/vagrant/token"

# Attendre que le token soit disponible
while [ ! -f "$TOKEN_FILE" ]; do
    echo "En attente du token K3s depuis le serveur maître..."
    sleep 2
done

# Lire le token depuis le fichier partagé
NODE_TOKEN=$(cat $TOKEN_FILE)

# Installation de K3s en tant que nœud agent
echo "Installation de K3s en mode agent..."
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" K3S_TOKEN="${NODE_TOKEN}" sh -

echo "Le nœud de travail K3s a été configuré et rejoint le cluster avec succès."
