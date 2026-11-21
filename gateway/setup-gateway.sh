#!/usr/bin/env bash
# =============================================================
# setup-gateway.sh - transforma a VM gw no gateway da rede
# =============================================================
# Roda em: gw (placa 1 = NAT/WAN, placa 2 = Rede Interna/LAN)
# Uso:     sudo bash gateway/setup-gateway.sh
#
# O que faz:
#   1. Configura as duas placas de rede (netplan)
#   2. Liga o repasse de pacotes entre as placas (ip_forward)
#   3. Cria as regras de NAT e de repasse (iptables)
#   4. Salva as regras para sobreviverem ao reboot
#
# Pode ser rodado mais de uma vez: o resultado é sempre o mesmo.
# =============================================================

set -euo pipefail
source "$(dirname "$0")/../config.env"

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"
    exit 1
fi

# -------------------------------------------------------------
# 1. Placas de rede (netplan)
# -------------------------------------------------------------
# WAN (enp0s3): recebe IP por DHCP do NAT do VirtualBox.
# LAN (enp0s8): IP fixo 192.168.10.1/24. Sem "gateway" aqui,
#   porque o gw É o gateway da LAN; a saída padrão dele é a WAN.
#
# O arquivo do instalador (00-installer-config.yaml) amarra a
# configuração ao MAC da VM base, que não existe no clone. Ele é
# guardado com outra extensão (o netplan só lê *.yaml) e trocado
# por um arquivo nosso, que identifica as placas pelo nome.
echo ">> 1. Configurando as placas de rede"

for antigo in /etc/netplan/00-installer-config.yaml /etc/netplan/50-cloud-init.yaml; do
    if [ -f "$antigo" ]; then
        mv "$antigo" "$antigo.bak"
        echo "   $antigo guardado como $antigo.bak"
    fi
done

cat > /etc/netplan/01-cardeal.yaml <<EOF
# Gerado por gateway/setup-gateway.sh - não editar à mão
network:
  version: 2
  ethernets:
    ${IF_WAN}:
      dhcp4: true
    ${IF_LAN}:
      dhcp4: false
      addresses:
        - ${IP_GW}/${PREFIXO}
EOF
# O netplan reclama se o arquivo puder ser lido por outros usuários
chmod 600 /etc/netplan/01-cardeal.yaml

netplan apply

# -------------------------------------------------------------
# 2. Repasse de pacotes (roteamento)
# -------------------------------------------------------------
# Por padrão o Linux descarta pacotes que não são para ele.
# Com ip_forward=1, ele passa a encaminhar pacotes de uma placa
# para outra: é isso que faz a máquina ser um roteador.
# O arquivo em /etc/sysctl.d/ mantém a configuração após reboot.
echo ">> 2. Ligando o repasse de pacotes (ip_forward)"

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-cardeal-forward.conf
sysctl -p /etc/sysctl.d/99-cardeal-forward.conf

# -------------------------------------------------------------
# 3. Regras de NAT e de repasse (iptables)
# -------------------------------------------------------------
# iptables-persistent salva as regras e recarrega no boot.
# As duas linhas do debconf respondem antes as perguntas que ele
# faria na instalação, para o script não parar esperando alguém.
echo ">> 3. Instalando iptables-persistent"

echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent

# Adiciona uma regra só se ela ainda não existir (-C confere).
# Assim, rodar o script de novo não duplica as regras.
regra() {
    iptables -C "$@" 2>/dev/null || iptables -A "$@"
}

echo ">> 4. Criando as regras"

# NAT: pacotes da LAN que saem pela WAN têm o IP de origem trocado
# pelo IP do gw (MASQUERADE = usa o IP que a WAN tiver no momento).
iptables -t nat -C POSTROUTING -s "${REDE}/${PREFIXO}" -o "$IF_WAN" -j MASQUERADE 2>/dev/null \
    || iptables -t nat -A POSTROUTING -s "${REDE}/${PREFIXO}" -o "$IF_WAN" -j MASQUERADE

# Repasse: a LAN pode iniciar conexões para fora...
regra FORWARD -i "$IF_LAN" -o "$IF_WAN" -j ACCEPT
# ...e de fora só entram respostas de conexões que a LAN abriu.
regra FORWARD -i "$IF_WAN" -o "$IF_LAN" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
# Todo o resto que tentar atravessar o gw é descartado.
iptables -P FORWARD DROP

netfilter-persistent save

# -------------------------------------------------------------
# 5. Verificação
# -------------------------------------------------------------
echo ">> 5. Verificando"
echo "--- Endereços:"
ip -br addr show "$IF_WAN"
ip -br addr show "$IF_LAN"
echo "--- ip_forward (esperado: 1):"
sysctl -n net.ipv4.ip_forward
echo "--- Regra de NAT:"
iptables -t nat -S POSTROUTING
echo "--- Regras de repasse:"
iptables -S FORWARD

echo ">> Pronto. O gw está roteando ${REDE}/${PREFIXO} para a internet."
