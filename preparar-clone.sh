#!/usr/bin/env bash
# =============================================================
# preparar-clone.sh - dá identidade própria a um clone da VM base
# =============================================================
# Roda em: qualquer VM clonada da base, logo depois do clone
# Uso:     sudo bash preparar-clone.sh <nome>     (ex.: gw, cliente)
#          depois: sudo reboot
#
# Um clone é uma cópia idêntica da base, inclusive no que deveria
# ser único por máquina. Este script troca:
#   1. o hostname (nome da máquina)
#   2. o machine-id (o cliente DHCP usa: clones iguais recebem o
#      mesmo IP)
#   3. as chaves SSH do servidor (a "identidade" da máquina para
#      quem conecta por SSH)
#
# No VirtualBox, clonar com "Full clone" e "Generate new MAC
# addresses for all network adapters".
# =============================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0 <nome>"
    exit 1
fi

NOVO="${1:?Informe o nome da máquina. Ex.: sudo bash $0 gw}"
ATUAL=$(hostname)

echo ">> 1. Hostname: $ATUAL -> $NOVO"
hostnamectl set-hostname "$NOVO"
# Troca o nome antigo também no /etc/hosts (\b = palavra inteira)
sed -i "s/\b${ATUAL}\b/${NOVO}/" /etc/hosts

echo ">> 2. Gerando um machine-id novo"
rm -f /etc/machine-id
systemd-machine-id-setup

echo ">> 3. Gerando chaves SSH novas"
rm -f /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

echo ">> Pronto. Reinicie com: sudo reboot"
echo "   Quem já tinha conectado nesta máquina por SSH vai ver o aviso"
echo "   'REMOTE HOST IDENTIFICATION HAS CHANGED'. Para limpar:"
echo "   ssh-keygen -R <ip-da-maquina>"
