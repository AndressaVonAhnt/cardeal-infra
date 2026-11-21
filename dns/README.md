# dns

**VM:** gw · **Responsável:** Andressa

Servidor **BIND9** com dois papéis:

- **autoritativo** para `cardeal.local`: responde os nomes da empresa a partir dos arquivos de zona;
- **recursivo com encaminhamento** para o resto (`google.com` etc.): pergunta ao `8.8.8.8` e devolve a resposta.

Escuta só em `127.0.0.1` e `192.168.10.1` (nunca na WAN) e só aceita perguntas da LAN.

| Nome | Tipo | Valor |
|---|---|---|
| `cardeal.local` | MX | `10 mail.cardeal.local.` |
| `ns`, `gw` | A | 192.168.10.1 |
| `srv`, `www`, `arquivos` | A | 192.168.10.10 |
| `mail` | A | 192.168.10.20 |
| 192.168.10.1 / .10 / .20 | PTR | `gw` / `srv` / `mail` `.cardeal.local.` |

Arquivo: `setup-dns.sh`. Ele gera, a partir do `config.env`:

- `/etc/bind/named.conf.options` (opções)
- `/etc/bind/named.conf.local` (declaração das zonas)
- `/etc/bind/db.cardeal.local` (zona direta)
- `/etc/bind/db.192.168.10` (zona reversa)

Testar: `dig @192.168.10.1 www.cardeal.local`, `dig @192.168.10.1 MX cardeal.local`, `dig @192.168.10.1 -x 192.168.10.10`.
