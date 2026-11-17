# dns

**VM:** gw · **Responsável:** Pessoa A

BIND9 com a zona `cardeal.local` (www, arquivos, mail, MX) e repasse dos outros nomes para `DNS_EXTERNO`.

- `setup-dns.sh`
- `db.cardeal.local`: arquivo de zona

Testar: `dig www.cardeal.local @192.168.10.1`.
