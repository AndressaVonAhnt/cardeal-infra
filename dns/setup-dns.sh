#!/usr/bin/env bash
# =============================================================
# setup-dns.sh - servidor DNS da empresa (BIND9) no gw
# =============================================================
# Roda em: gw (depois do gateway/setup-gateway.sh)
# Uso:     sudo bash dns/setup-dns.sh
#
# O que faz:
#   1. Instala o BIND9
#   2. Configura as opções: onde escuta, quem pode perguntar e
#      para onde encaminhar os nomes que não são da empresa
#   3. Cria a zona cardeal.local (nome -> IP) e a zona reversa
#      (IP -> nome) a partir dos valores do config.env
#   4. Valida tudo, reinicia o serviço e testa
#
# Pode ser rodado mais de uma vez: o resultado é sempre o mesmo.
# Logs do servidor: journalctl -u named
# =============================================================

set -euo pipefail
source "$(dirname "$0")/../config.env"

if [ "$(id -u)" -ne 0 ]; then
    echo "Rode com sudo: sudo bash $0"
    exit 1
fi

# Partes do endereço da rede, para montar a zona reversa.
# Ex.: REDE=192.168.10.0 -> zona 10.168.192.in-addr.arpa
IFS=. read -r O1 O2 O3 _ <<< "$REDE"
ZONA_REVERSA="${O3}.${O2}.${O1}.in-addr.arpa"

# Número de série da zona: ano, mês, dia e hora (AAAAMMDDHH).
# Ele precisa aumentar a cada alteração da zona.
SERIAL=$(date +%Y%m%d%H)

# -------------------------------------------------------------
# 1. Instalação
# -------------------------------------------------------------
# bind9:       o servidor (programa "named")
# bind9-utils: named-checkconf e named-checkzone (validação)
# bind9-dnsutils: dig (testes)
echo ">> 1. Instalando o BIND9"
DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 bind9-utils bind9-dnsutils

# Guarda os arquivos originais do pacote, só na primeira vez.
for f in /etc/bind/named.conf.options /etc/bind/named.conf.local; do
    [ -f "$f.orig" ] || cp "$f" "$f.orig"
done

# -------------------------------------------------------------
# 2. Opções gerais
# -------------------------------------------------------------
echo ">> 2. Escrevendo /etc/bind/named.conf.options"
cat > /etc/bind/named.conf.options <<EOF
// Gerado por dns/setup-dns.sh - não editar à mão

// Quem pode usar este DNS: o próprio gw e a LAN da empresa.
acl "cardeal" {
    127.0.0.1;
    ${REDE}/${PREFIXO};
};

options {
    directory "/var/cache/bind";

    // Escuta só no próprio gw e na LAN, nunca na WAN.
    // Também evita conflito com o systemd-resolved, que já usa a
    // porta 53 no endereço 127.0.0.53.
    listen-on port 53 { 127.0.0.1; ${IP_GW}; };
    listen-on-v6 { none; };

    // Só a empresa pode perguntar e pedir resolução de nomes de
    // fora (evita virar um "resolvedor aberto" na internet).
    allow-query     { cardeal; };
    recursion yes;
    allow-recursion { cardeal; };

    // Nomes que não são da empresa (google.com etc.) são perguntados
    // a este servidor externo. "forward only": sempre pergunta a ele,
    // em vez de percorrer a hierarquia do DNS a partir da raiz.
    forwarders { ${DNS_EXTERNO}; };
    forward only;

    dnssec-validation auto;
};
EOF

# -------------------------------------------------------------
# 3. Zonas
# -------------------------------------------------------------
echo ">> 3. Declarando as zonas em /etc/bind/named.conf.local"
cat > /etc/bind/named.conf.local <<EOF
// Gerado por dns/setup-dns.sh - não editar à mão

// Zona direta: nomes do domínio -> IPs
zone "${DOMINIO}" {
    type primary;
    file "/etc/bind/db.${DOMINIO}";
};

// Zona reversa: IPs da rede ${REDE}/${PREFIXO} -> nomes
zone "${ZONA_REVERSA}" {
    type primary;
    file "/etc/bind/db.${O1}.${O2}.${O3}";
};
EOF

echo ">> 4. Escrevendo a zona ${DOMINIO}"
cat > "/etc/bind/db.${DOMINIO}" <<EOF
; Gerado por dns/setup-dns.sh - não editar à mão
; Zona direta de ${DOMINIO}: nome -> IP
;
; \$TTL: por quanto tempo (segundos) quem perguntou pode guardar a
; resposta em cache antes de perguntar de novo.
\$TTL 3600

; SOA: servidor principal da zona, e-mail do responsável (o primeiro
; "." vira "@": admin@${DOMINIO}) e os tempos da zona.
@   IN  SOA ns.${DOMINIO}. admin.${DOMINIO}. (
        ${SERIAL}  ; serial: AAAAMMDDHH, aumenta a cada alteração
        3600        ; refresh
        900         ; retry
        604800      ; expire
        3600 )      ; TTL das respostas negativas ("não existe")

; Quem responde por esta zona
@   IN  NS  ns.${DOMINIO}.

; Quem recebe os e-mails de @${DOMINIO} (10 = prioridade)
@   IN  MX  10 mail.${DOMINIO}.

; Nomes -> IPs
ns        IN  A  ${IP_GW}
gw        IN  A  ${IP_GW}
srv       IN  A  ${IP_SRV}
www       IN  A  ${IP_SRV}
arquivos  IN  A  ${IP_SRV}
mail      IN  A  ${IP_MAIL}
EOF

echo ">> 5. Escrevendo a zona reversa ${ZONA_REVERSA}"
cat > "/etc/bind/db.${O1}.${O2}.${O3}" <<EOF
; Gerado por dns/setup-dns.sh - não editar à mão
; Zona reversa de ${REDE}/${PREFIXO}: IP -> nome
\$TTL 3600
@   IN  SOA ns.${DOMINIO}. admin.${DOMINIO}. (
        ${SERIAL} 3600 900 604800 3600 )
@   IN  NS  ns.${DOMINIO}.

; Último número do IP -> nome completo (com "." no final)
${IP_GW##*.}    IN  PTR  gw.${DOMINIO}.
${IP_SRV##*.}   IN  PTR  srv.${DOMINIO}.
${IP_MAIL##*.}  IN  PTR  mail.${DOMINIO}.
EOF

# -------------------------------------------------------------
# 4. Validação e serviço
# -------------------------------------------------------------
# Confere a sintaxe antes de reiniciar. Se algo estiver errado,
# o set -e para aqui e o serviço continua com a configuração antiga.
echo ">> 6. Validando"
named-checkconf
named-checkzone "${DOMINIO}" "/etc/bind/db.${DOMINIO}"
named-checkzone "${ZONA_REVERSA}" "/etc/bind/db.${O1}.${O2}.${O3}"

echo ">> 7. Reiniciando o serviço"
systemctl enable named
systemctl restart named

# -------------------------------------------------------------
# 5. Verificação
# -------------------------------------------------------------
echo ">> 8. Verificando"
echo "--- Serviço (esperado: active):"
systemctl is-active named
echo "--- Escutando na porta 53 (esperado: 127.0.0.1 e ${IP_GW}):"
ss -ulnp | grep ':53 ' | grep named || true
echo "--- www.${DOMINIO} (esperado: ${IP_SRV}):"
dig +short @"${IP_GW}" "www.${DOMINIO}"
echo "--- MX de ${DOMINIO} (esperado: 10 mail.${DOMINIO}.):"
dig +short @"${IP_GW}" MX "${DOMINIO}"
echo "--- Reverso de ${IP_SRV} (esperado: srv.${DOMINIO}.):"
dig +short @"${IP_GW}" -x "${IP_SRV}"
echo "--- Nome de fora, google.com (esperado: um ou mais IPs):"
dig +short @"${IP_GW}" google.com

echo ">> Pronto. DNS de ${DOMINIO} respondendo em ${IP_GW}."
