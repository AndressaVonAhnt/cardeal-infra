# dhcp

**VM:** gw · **Responsável:** Pessoa A

Servidor isc-dhcp-server entregando IP da faixa `DHCP_INICIO`–`DHCP_FIM`, máscara, gateway e DNS na placa da LAN.

- `setup-dhcp.sh`

Testar: no cliente, `ip a` mostra um IP entre .100 e .200.
