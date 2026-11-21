#!/usr/bin/env bash
# =============================================================
# testar-rede.sh - confere, a partir do cliente, se todos os
#                  serviços da rede da Cardeal estão funcionando
# =============================================================
# Roda em: cliente (como usuário comum, sem sudo)
# Uso:     bash cliente/testar-rede.sh              (testes rápidos)
#          bash cliente/testar-rede.sh --completo   (+ login no Samba,
#                                                    envio e leitura de e-mail;
#                                                    pede as senhas)
#
# Cada teste mostra OK ou FALHA. No fim, um resumo. O código de
# saída é o número de falhas (0 = tudo certo).
#
# Ordem para ligar as VMs antes de testar: gw -> srv e mail -> cliente
# =============================================================

set -uo pipefail     # sem -e: um teste que falha não interrompe os outros
source "$(dirname "$0")/../config.env"

COMPLETO=false
[ "${1:-}" = "--completo" ] && COMPLETO=true

VERDE=$'\e[32m'; VERMELHO=$'\e[31m'; NEGRITO=$'\e[1m'; FIM=$'\e[0m'
OKS=0; FALHAS=0

# ok "descrição"  /  falha "descrição" "dica do que olhar"
ok()    { echo "  ${VERDE}[ OK  ]${FIM} $1"; OKS=$((OKS + 1)); }
falha() { echo "  ${VERMELHO}[FALHA]${FIM} $1"; echo "          -> $2"; FALHAS=$((FALHAS + 1)); }
secao() { echo; echo "${NEGRITO}$1${FIM}"; }

# Abre uma conexão TCP e lê a primeira linha que o servidor enviar
# (a "saudação" de protocolos como SMTP e IMAP). Usa o /dev/tcp do bash.
saudacao() {   # saudacao host porta
    timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2 && head -n 1 <&3" 2>/dev/null | tr -d '\r'
}

# Só testa se a porta TCP aceita conexão (para serviços sem saudação).
porta_aberta() {   # porta_aberta host porta
    timeout 5 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null
}

# Primeira resposta do DNS para um nome (vazio se não resolver).
resolve() {   # resolve [tipo] nome
    dig +short +time=2 +tries=1 "$@" 2>/dev/null | head -n 1
}

echo "${NEGRITO}Teste da rede Cardeal Ltda (${DOMINIO}) - $(hostname), $(date '+%d/%m/%Y %H:%M')${FIM}"

# -------------------------------------------------------------
secao "1. DHCP: o cliente recebeu a configuração da rede?"
# -------------------------------------------------------------
MEU_IP=$(ip -4 -o addr show "$IF_UNICA" 2>/dev/null | awk '{print $4}' | cut -d/ -f1)
if [ -n "$MEU_IP" ] && [ "${MEU_IP%.*}" = "${DHCP_INICIO%.*}" ] \
   && [ "${MEU_IP##*.}" -ge "${DHCP_INICIO##*.}" ] && [ "${MEU_IP##*.}" -le "${DHCP_FIM##*.}" ]; then
    ok "IP ${MEU_IP} dentro da faixa do DHCP (${DHCP_INICIO} - ${DHCP_FIM})"
else
    falha "IP da ${IF_UNICA}: '${MEU_IP:-nenhum}', fora da faixa do DHCP" \
          "o Kea está rodando no gw? (systemctl is-active kea-dhcp4-server)"
fi

if ip route show default | grep -q "via ${IP_GW}"; then
    ok "Rota padrão via ${IP_GW} (gateway recebido pelo DHCP)"
else
    falha "Rota padrão não aponta para ${IP_GW}" "confira: ip route"
fi

if ping -c 1 -W 2 "$IP_GW" >/dev/null 2>&1; then
    ok "Gateway ${IP_GW} responde (ping)"
else
    falha "Gateway ${IP_GW} não responde" "o gw está ligado? a placa do cliente está na Rede Interna cardeal-lan?"
fi

# -------------------------------------------------------------
secao "2. DNS: os nomes da empresa resolvem?"
# -------------------------------------------------------------
for par in "www:${IP_SRV}" "arquivos:${IP_SRV}" "mail:${IP_MAIL}"; do
    nome="${par%%:*}.${DOMINIO}"; esperado="${par#*:}"
    obtido=$(resolve "$nome")
    if [ "$obtido" = "$esperado" ]; then
        ok "${nome} -> ${obtido}"
    else
        falha "${nome} -> '${obtido:-sem resposta}' (esperado ${esperado})" \
              "o BIND está rodando no gw? (systemctl is-active named)"
    fi
done

mx=$(resolve MX "$DOMINIO")
if [ "$mx" = "10 mail.${DOMINIO}." ]; then
    ok "MX de ${DOMINIO} -> ${mx}"
else
    falha "MX de ${DOMINIO} -> '${mx:-sem resposta}'" "confira o registro MX na zona do gw"
fi

# -------------------------------------------------------------
secao "3. Web (HTTP): o site da empresa abre?"
# -------------------------------------------------------------
codigo=$(curl -s -o /tmp/cardeal-pagina.html -w '%{http_code}' --max-time 5 "http://www.${DOMINIO}/")
if [ "$codigo" = "200" ] && grep -q "Cardeal" /tmp/cardeal-pagina.html; then
    ok "http://www.${DOMINIO}/ respondeu 200 OK com a página da Cardeal"
else
    falha "http://www.${DOMINIO}/ respondeu '${codigo}'" \
          "o srv está ligado em ${IP_SRV}? (systemctl is-active apache2)"
fi

# -------------------------------------------------------------
secao "4. Arquivos (SMB): o compartilhamento responde?"
# -------------------------------------------------------------
if porta_aberta "arquivos.${DOMINIO}" 445; then
    ok "arquivos.${DOMINIO} aceita conexões na porta 445 (SMB)"
else
    falha "arquivos.${DOMINIO} não responde na porta 445" "o Samba está rodando no srv? (systemctl is-active smbd)"
fi

if $COMPLETO; then
    echo "     Senha do usuário funcionario (Samba):"
    if smbclient "//arquivos.${DOMINIO}/compartilhado" -U funcionario -c 'ls' >/dev/null 2>&1; then
        ok "Login como funcionario e listagem da pasta compartilhado"
    else
        falha "Não foi possível entrar na pasta compartilhado" "confira a senha do funcionario e a seção [compartilhado] do smb.conf"
    fi
fi

# -------------------------------------------------------------
secao "5. E-mail (SMTP e IMAP): os servidores respondem?"
# -------------------------------------------------------------
s=$(saudacao "mail.${DOMINIO}" 25)
if [[ "$s" == 220* ]]; then
    ok "SMTP (porta 25): ${s}"
else
    falha "SMTP (porta 25) sem a saudação 220" "o Postfix está rodando no mail? (systemctl is-active postfix)"
fi

s=$(saudacao "mail.${DOMINIO}" 143)
if [[ "$s" == "* OK"* ]]; then
    ok "IMAP (porta 143): ${s:0:60}"
else
    falha "IMAP (porta 143) sem a saudação * OK" "o Dovecot está rodando no mail? (systemctl is-active dovecot)"
fi

if $COMPLETO; then
    assunto="Teste automatico $(date +%s)"
    printf 'Subject: %s\n\nMensagem enviada pelo testar-rede.sh.\n' "$assunto" > /tmp/cardeal-msg.txt
    if curl -s --max-time 10 "smtp://mail.${DOMINIO}" \
            --mail-from "ana@${DOMINIO}" --mail-rcpt "joao@${DOMINIO}" -T /tmp/cardeal-msg.txt; then
        ok "E-mail enviado de ana@${DOMINIO} para joao@${DOMINIO}"
        sleep 2   # tempo para o Postfix entregar na caixa
        echo "     Senha do usuário joao (e-mail):"
        read -rsp "     > " SENHA_JOAO; echo
        if curl -s --max-time 10 -u "joao:${SENHA_JOAO}" "imap://mail.${DOMINIO}/INBOX" \
                -X "SEARCH SUBJECT \"${assunto}\"" | grep -qE '^\* SEARCH [0-9]+'; then
            ok "Mensagem encontrada na caixa do joao (IMAP)"
        else
            falha "Mensagem não encontrada na caixa do joao" "confira a senha e o log do mail: journalctl -u postfix"
        fi
    else
        falha "Envio pelo SMTP recusado" "confira mynetworks e mydestination no Postfix"
    fi
fi

# -------------------------------------------------------------
secao "6. Internet: a empresa alcança o mundo de fora?"
# -------------------------------------------------------------
if ping -c 1 -W 3 "$DNS_EXTERNO" >/dev/null 2>&1; then
    ok "Ping em ${DNS_EXTERNO}: roteamento e NAT do gw funcionando"
else
    falha "Sem resposta de ${DNS_EXTERNO}" "no gw: ip_forward = 1? regra MASQUERADE? (sudo iptables -t nat -S)"
fi

externo=$(resolve google.com)
if [ -n "$externo" ]; then
    ok "google.com -> ${externo} (DNS do gw encaminhando para fora)"
else
    falha "google.com não resolveu" "confira os forwarders do BIND no gw"
fi

# -------------------------------------------------------------
echo
if [ "$FALHAS" -eq 0 ]; then
    echo "${VERDE}${NEGRITO}Resultado: ${OKS} OK, 0 falhas. A rede da Cardeal está funcionando.${FIM}"
else
    echo "${VERMELHO}${NEGRITO}Resultado: ${OKS} OK, ${FALHAS} falha(s). Veja as dicas acima.${FIM}"
fi
$COMPLETO || echo "(Para testar também login no Samba e envio/leitura de e-mail: --completo)"
exit "$FALHAS"
