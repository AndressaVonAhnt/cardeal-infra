#!/usr/bin/env bash
# =============================================================
# setup-samba.sh - pasta compartilhada na srv (Samba)
# =============================================================
# Uso:  sudo bash samba/setup-samba.sh
# =============================================================

# Script para:
# - no primeiro erro (-e)
# - em variável não definida (-u)
# - em erro no meio de um pipe (-o pipefail)
set -euo pipefail

# Carrega os valores compartilhados (IPs, domínio, placas)
source "$(dirname "$0")/../config.env"

# Precisa rodar como root (instala pacotes e edita /etc).
if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"
    exit 1
fi

echo ">> 1. Instalando pacotes"
apt-get update
apt-get install -y samba smbclient

echo ">> 2. Escrevendo arquivos de configuração"
mkdir -p /srv/compartilhado
ls -ld /srv/compartilhado
if ! grep -q "^\[compartilhado\]" /etc/samba/smb.conf; then
cat >> /etc/samba/smb.conf <<EOF

[compartilhado]
   path = /srv/compartilhado
   read only = no
   valid users = funcionario
EOF
fi
SENHA_SAMBA="cardeal123"
id funcionario &>/dev/null || useradd -M -s /usr/sbin/nologin funcionario
(echo "$SENHA_SAMBA"; echo "$SENHA_SAMBA") | smbpasswd -s -a funcionario
chown funcionario /srv/compartilhado

echo ">> 3. Reiniciando o serviço"
systemctl restart smbd
systemctl enable smbd

echo ">> 4. Verificando"
systemctl is-active smbd

echo ">> Pronto."
