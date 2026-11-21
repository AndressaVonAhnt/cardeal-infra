#!/usr/bin/env bash
# =============================================================
# setup-web.sh - Apache na srv (www.cardeal.local)
# =============================================================
# Uso:  sudo bash web/setup-web.sh        (instala e configura o Apache)
#       sudo bash web/setup-web.sh rede   (idem + IP fixo, no Encontro 2)
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
apt-get install -y apache2

echo ">> 2. Escrevendo arquivos de configuração"
cp "$(dirname "$0")/index.html" /var/www/html/index.html
sed -i 's/#ServerName www.example.com/ServerName www.cardeal.local/' /etc/apache2/sites-available/000-default.conf

echo ">> 3. Reiniciando o serviço"
systemctl restart apache2
systemctl enable apache2

echo ">> 4. Verificando"
systemctl is-active apache2

echo ">> 5. IP fixo"
if [ "${1:-}" = "rede" ]; then
cat > /etc/netplan/00-installer-config.yaml <<EOF
network:
  version: 2
  ethernets:
    ${IF_UNICA}:
      dhcp4: false
      addresses:
        - ${IP_SRV}/${PREFIXO}
      routes:
        - to: default
          via: ${IP_GW}
      nameservers:
        addresses: [${IP_GW}]
        search: [${DOMINIO}]
EOF
    chmod 600 /etc/netplan/00-installer-config.yaml
    netplan apply
    echo "IP fixo aplicado"
else
    echo "Pulando IP fixo (rode com 'rede' para aplicar)"
fi

echo ">> Pronto."
