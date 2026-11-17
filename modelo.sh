# !/usr/bin/env bash
# =============================================================
# modelo.sh - esqueleto de cada script 
# =============================================================
# Uso:  cp modelo.sh pasta/setup-algo.sh
#       sudo bash pasta/setup-algo.sh
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
# apt-get install -y <pacotes>

echo ">> 2. Escrevendo arquivos de configuração"
# cat > /etc/caminho/arquivo.conf <<EOF
# conteúdo, pode usar ${IP_GW}, ${DOMINIO}...
# EOF

echo ">> 3. Reiniciando o serviço"
# systemctl restart <servico>
# systemctl enable <servico>

echo ">> 4. Verificando"
# systemctl is-active <servico>

echo ">> Pronto."
