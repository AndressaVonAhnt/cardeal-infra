# dhcp

**VM:** gw · **Responsável:** Andressa

Servidor **Kea DHCPv4** (sucessor oficial do isc-dhcp-server) entregando, só na placa da LAN (`enp0s8`):

- IP da faixa `192.168.10.100` a `192.168.10.200`
- máscara `255.255.255.0` (/24)
- gateway e DNS `192.168.10.1`
- domínio `cardeal.local`

Arquivo: `setup-dhcp.sh` (gera `/etc/kea/kea-dhcp4.conf`).

Testar: no cliente, `ip a` mostra um IP entre .100 e .200. No gw, `journalctl -u kea-dhcp4-server` mostra o empréstimo.
