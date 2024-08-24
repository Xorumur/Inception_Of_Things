#!/bin/bash

echo "VMs actuellement gérées par libvirt:"
virsh list --all
for domain in $(virsh list --name); do
    echo "Arrêt de la VM: $domain"
    virsh destroy "$domain"
done

for domain in $(virsh list --all --name); do
    echo "Suppression de la VM: $domain"
    virsh undefine "$domain" --remove-all-storage
done

rm k3s.yaml
rm token
rm -rf ./.vagrant
vagrant destroy -f
echo "Toutes les VMs ont été supprimées."