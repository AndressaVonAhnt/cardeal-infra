#!/usr/bin/env bash
# =============================================================
# setup-dhcp.sh - servidor DHCP da LAN (Kea) no gw
# =============================================================
# Roda em: gw (depois do gateway/setup-gateway.sh)
# Uso:     sudo bash dhcp/setup-dhcp.sh
#
# O que faz:
#   1. Instala o Kea DHCPv4 (sucessor oficial do isc-dhcp-server)
#   2. Escreve /etc/kea/kea-dhcp4.conf com a faixa e as opções
#   3. Valida o arquivo, reinicia o serviço e mostra o estado
#
# Pode ser rodado mais de uma vez: o resultado é sempre o mesmo.
# Logs do servidor: journalctl -u kea-dhcp4-server
# =============================================================

set -euo pipefail
source "$(dirname "$0")/../config.env"

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"
    exit 1
fi

CONF=/etc/kea/kea-dhcp4.conf

# -------------------------------------------------------------
# 1. Instalação
# -------------------------------------------------------------
# Só o servidor DHCPv4. O pacote "kea" completo traria também o
# agente de controle (API REST), que não usamos.
echo ">> 1. Instalando o Kea DHCPv4"
DEBIAN_FRONTEND=noninteractive apt-get install -y kea-dhcp4-server

# -------------------------------------------------------------
# 2. Configuração
# -------------------------------------------------------------
# Guarda o arquivo de exemplo que vem com o pacote, só na
# primeira vez (para não sobrescrever o original com o nosso).
if [ -f "$CONF" ] && [ ! -f "$CONF.orig" ]; then
    cp "$CONF" "$CONF.orig"
fi

echo ">> 2. Escrevendo $CONF"
cat > "$CONF" <<EOF
// Gerado por dhcp/setup-dhcp.sh - não editar à mão
{
  "Dhcp4": {
    // Atende SÓ a placa da LAN. Sem isso o gw responderia
    // pedidos de DHCP também pela WAN (rede do VirtualBox).
    "interfaces-config": {
      "interfaces": [ "${IF_LAN}" ]
    },

    // Onde guardar os empréstimos (leases): um arquivo CSV em
    // /var/lib/kea/. "persist" mantém os leases após reiniciar;
    // "lfc-interval" limpa o arquivo de hora em hora.
    "lease-database": {
      "type": "memfile",
      "persist": true,
      "lfc-interval": 3600
    },

    // Duração do empréstimo do IP, em segundos. 10 minutos é curto
    // de propósito: no laboratório dá para ver a renovação acontecer.
    "valid-lifetime": 600,
    "max-valid-lifetime": 7200,

    "subnet4": [
      {
        "id": 1,
        "subnet": "${REDE}/${PREFIXO}",

        // Faixa entregue aos clientes. Os IPs abaixo de .100 ficam
        // fora: são os IPs fixos dos servidores (.1, .10, .20).
        "pools": [
          { "pool": "${DHCP_INICIO} - ${DHCP_FIM}" }
        ],

        // O que o cliente recebe além do IP.
        // A máscara sai do próprio "subnet" (/24).
        "option-data": [
          { "name": "routers",             "data": "${IP_GW}" },
          { "name": "domain-name-servers", "data": "${IP_GW}" },
          { "name": "domain-name",         "data": "${DOMINIO}" }
        ]
      }
    ]
  }
}
EOF

# -------------------------------------------------------------
# 3. Validação e serviço
# -------------------------------------------------------------
# O Kea roda como o usuário _kea, e a pasta /etc/kea é dele (750).
# Dono root:_kea e modo 640: o Kea lê pelo grupo, outros usuários
# não leem (a configuração do Kea pode conter senhas).
chown root:_kea "$CONF"
chmod 640 "$CONF"

# -t só confere o arquivo, sem iniciar o servidor. Se houver erro,
# o set -e para o script aqui, antes de reiniciar o serviço.
# Roda como _kea: como root, o AppArmor do Ubuntu proíbe o kea-dhcp4
# de usar as permissões especiais do root (dac_override) para entrar
# na pasta /etc/kea, e a validação falha com "Unable to open file".
echo ">> 3. Validando a configuração"
runuser -u _kea -- kea-dhcp4 -t "$CONF"

echo ">> 4. Reiniciando o serviço"
systemctl enable kea-dhcp4-server
systemctl restart kea-dhcp4-server

# -------------------------------------------------------------
# 4. Verificação
# -------------------------------------------------------------
echo ">> 5. Verificando"
echo "--- Serviço (esperado: active):"
systemctl is-active kea-dhcp4-server
echo "--- Escutando na porta UDP 67:"
ss -ulnp | grep ':67 ' || echo "   (nada na porta 67 - confira: journalctl -u kea-dhcp4-server)"

echo ">> Pronto. Faixa ${DHCP_INICIO} - ${DHCP_FIM} na ${IF_LAN}."
