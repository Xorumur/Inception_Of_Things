sudo apt-get update
sudo apt-get install -y docker.io

curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash

curl -LO https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl

chmod +x ./kubectl

sudo mv ./kubectl /usr/local/bin/kubectl

kubectl version --client