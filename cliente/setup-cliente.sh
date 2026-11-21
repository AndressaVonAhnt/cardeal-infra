#!/usr/bin/env bash
# =============================================================
# setup-cliente.sh - "computador do funcionário" com interface
#                    gráfica leve (i3) e as ferramentas de teste
# =============================================================
# Roda em: cliente (só na Rede Interna, IP por DHCP)
# Uso:     sudo bash cliente/setup-cliente.sh
#          depois, para abrir a interface gráfica: startx
#
# O que faz:
#   1. Rede: DHCP explícito no netplan, usando o domínio que o
#      DHCP envia (resolve o problema dos nomes .local)
#   2. Instala a interface gráfica (Xorg + i3)
#   3. Instala os programas de teste (Firefox, Thunderbird,
#      Wireshark, dig, smbclient, curl)
#   4. Instala os Guest Additions (copiar/colar com o notebook)
#   5. Configura o i3, o xterm e o startx para o usuário
#
# Pode ser rodado mais de uma vez: o resultado é sempre o mesmo.
# =============================================================

set -euo pipefail
source "$(dirname "$0")/../config.env"

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"
    exit 1
fi

# Usuário que chamou o sudo: é na home dele que ficam as
# configurações do i3 (rodando com sudo, $HOME seria a do root).
USUARIO="${SUDO_USER:?Rode com sudo a partir do seu usuário}"
CASA=$(getent passwd "$USUARIO" | cut -d: -f6)

# -------------------------------------------------------------
# 1. Rede
# -------------------------------------------------------------
# O arquivo do instalador está amarrado ao MAC da VM base (não
# existe no clone). Ele é guardado como .bak e trocado por um
# arquivo que identifica a placa pelo nome.
#
# use-domains: usa o domínio que o Kea envia (opção domain-name).
# search: garante o domínio mesmo assim. Com cardeal.local
#   configurado na placa, o systemd-resolved manda os nomes .local
#   para o DNS da rede, em vez de tratá-los como mDNS e recusar.
echo ">> 1. Configurando a rede (DHCP)"

for antigo in /etc/netplan/00-installer-config.yaml /etc/netplan/50-cloud-init.yaml; do
    if [ -f "$antigo" ]; then
        mv "$antigo" "$antigo.bak"
        echo "   $antigo guardado como $antigo.bak"
    fi
done

cat > /etc/netplan/01-cardeal.yaml <<EOF
# Gerado por cliente/setup-cliente.sh - não editar à mão
network:
  version: 2
  ethernets:
    ${IF_UNICA}:
      dhcp4: true
      dhcp4-overrides:
        use-domains: true
      nameservers:
        search: [ ${DOMINIO} ]
EOF
chmod 600 /etc/netplan/01-cardeal.yaml
netplan apply
# Dá tempo de o DHCP responder antes de usar a rede para o apt.
sleep 5

# -------------------------------------------------------------
# 2. Interface gráfica
# -------------------------------------------------------------
# xserver-xorg: o servidor gráfico (desenha na tela)
# xinit:        o comando startx, que liga o Xorg e o i3
# i3:           gerenciador de janelas leve (lado a lado)
# xterm:        terminal gráfico simples
# x11-xkb-utils: setxkbmap, para o teclado ABNT2 no modo gráfico
# x11-xserver-utils: xrdb, que carrega as preferências do xterm
echo ">> 2. Instalando a interface gráfica (Xorg + i3)"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xserver-xorg xinit i3 xterm x11-xkb-utils x11-xserver-utils

# -------------------------------------------------------------
# 3. Programas de teste
# -------------------------------------------------------------
# A pergunta do Wireshark ("permitir captura para usuários comuns?")
# é respondida antes com "sim", para o script não parar esperando.
echo ">> 3. Instalando os programas de teste"
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    firefox thunderbird wireshark \
    bind9-dnsutils smbclient curl

# Quem está no grupo "wireshark" pode capturar pacotes sem sudo.
usermod -aG wireshark "$USUARIO"

# -------------------------------------------------------------
# 4. Guest Additions
# -------------------------------------------------------------
# Programas que conversam com o VirtualBox: área de transferência
# compartilhada (copiar/colar com o notebook) e ajuste da tela.
echo ">> 4. Instalando os Guest Additions"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    virtualbox-guest-utils virtualbox-guest-x11

# -------------------------------------------------------------
# 5. Configuração do i3 e do startx para o usuário
# -------------------------------------------------------------
echo ">> 5. Configurando o i3 para $USUARIO"

# startx lê o ~/.xinitrc: carrega as preferências do xterm
# (~/.Xresources) e abre o i3.
cat > "$CASA/.xinitrc" <<'FIM'
xrdb -merge ~/.Xresources
exec i3
FIM

# Preferências do xterm:
#   - Ctrl+Shift+C / Ctrl+Shift+V copiam e colam na área de
#     transferência (a mesma do Ctrl+C do notebook). Sem isso, o
#     xterm só cola a seleção do mouse (Shift+Insert / botão do meio).
#   - fonte maior e mais legível
# Valem para os dois nomes do programa: XTerm (o "xterm") e UXTerm
# (a variante com UTF-8 que o Alt+Enter do i3 abre).
cat > "$CASA/.Xresources" <<'FIM'
XTerm*faceName: Monospace
XTerm*faceSize: 11
XTerm*selectToClipboard: true
XTerm*VT100.Translations: #override \n\
    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \n\
    Ctrl Shift <Key>V: insert-selection(CLIPBOARD)

UXTerm*faceName: Monospace
UXTerm*faceSize: 11
UXTerm*selectToClipboard: true
UXTerm*VT100.Translations: #override \n\
    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \n\
    Ctrl Shift <Key>V: insert-selection(CLIPBOARD)
FIM

# Parte da configuração padrão do i3 (assim ele não abre o assistente
# de primeira execução) e acrescenta no final:
#   - teclado ABNT2 no modo gráfico
#   - VBoxClient --clipboard: copiar/colar com o notebook
#   - VBoxClient --vmsvga: a tela se ajusta ao tamanho da janela
#   - um terminal já aberto ao entrar
# O "VBoxClient-all" não iniciava os serviços no i3; por isso cada
# serviço é chamado explicitamente.
mkdir -p "$CASA/.config/i3"
cp /etc/i3/config "$CASA/.config/i3/config"
cat >> "$CASA/.config/i3/config" <<'FIM'

# --- Acrescentado por cliente/setup-cliente.sh ---
exec --no-startup-id setxkbmap br
exec --no-startup-id VBoxClient --clipboard
exec --no-startup-id VBoxClient --vmsvga
exec --no-startup-id i3-sensible-terminal
FIM

chown -R "$USUARIO:$USUARIO" "$CASA/.xinitrc" "$CASA/.Xresources" "$CASA/.config"

# -------------------------------------------------------------
# 6. Verificação
# -------------------------------------------------------------
echo ">> 6. Verificando"
echo "--- IP (esperado: um da faixa ${DHCP_INICIO} - ${DHCP_FIM}):"
ip -br addr show "$IF_UNICA"
echo "--- Rota padrão (esperado: via ${IP_GW}):"
ip route show default
echo "--- DNS e domínio da placa (esperado: ${IP_GW} e ${DOMINIO}):"
resolvectl dns "$IF_UNICA"
resolvectl domain "$IF_UNICA"
echo "--- Nome da empresa pelo DNS (esperado: ${IP_SRV}):"
resolvectl query "www.${DOMINIO}" || true

echo ">> Pronto. Reinicie (sudo reboot), entre na janela do VirtualBox e rode: startx"
echo "   (o grupo wireshark só vale depois de entrar de novo)"
