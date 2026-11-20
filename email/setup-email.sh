#!/usr/bin/env bash
# =============================================================
# setup-email.sh - email na mail (Postfix + Dovecot)
# =============================================================
# Uso: sudo bash email/setup-email.sh
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
debconf-set-selections <<EOF
postfix postfix/main_mailer_type select Internet Site
postfix postfix/mailname string cardeal.local
EOF
DEBIAN_FRONTEND=noninteractive apt-get install -y postfix dovecot-imapd

echo ">> 2. Escrevendo arquivos de configuração"
postconf -e "myhostname = mail.${DOMINIO}"
postconf -e "mydomain = ${DOMINIO}"
postconf -e 'mydestination = $myhostname, $mydomain, localhost'
postconf -e "mynetworks = 127.0.0.0/8, ${REDE}/${PREFIXO}"
postconf -e "inet_interfaces = all"
postconf -e "home_mailbox = Maildir/"
cat > /etc/dovecot/conf.d/99-cardeal.conf <<EOF
mail_driver = maildir
mail_path = %{home}/Maildir
mail_inbox_path = %{home}/Maildir
auth_allow_cleartext = yes
ssl = no
EOF
SENHA_EMAIL="cardeal123"
for u in ana joao; do
    id "$u" &>/dev/null || useradd -m -s /usr/sbin/nologin "$u"
    echo "$u:$SENHA_EMAIL" | chpasswd
done

echo ">> 3. Reiniciando o serviço"
systemctl restart postfix dovecot
systemctl enable postfix dovecot

echo ">> 4. Verificando"
systemctl is-active postfix dovecot

echo ">> Pronto."
