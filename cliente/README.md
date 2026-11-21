# cliente

**VM:** cliente · **Responsável:** Andressa

O "computador do funcionário": única VM com interface gráfica (i3), usada para testar os serviços e fazer as capturas no Wireshark. Recebe IP pelo DHCP (faixa `.100` a `.200`).

| Arquivo | O que faz |
|---|---|
| `setup-cliente.sh` | rede por DHCP (com o domínio `cardeal.local`), Xorg + i3, Firefox, Thunderbird, Wireshark, dig, smbclient, curl e Guest Additions (copiar/colar) |
| `testar-rede.sh` | confere todos os serviços da rede e mostra OK/FALHA para cada um |

Uso:

```bash
sudo bash cliente/setup-cliente.sh      # uma vez; depois: sudo reboot e startx
bash cliente/testar-rede.sh             # testes rápidos (sem senha)
bash cliente/testar-rede.sh --completo  # + login no Samba e envio/leitura de e-mail
```

Atalhos do i3: `Alt+Enter` terminal · `Alt+d` menu de programas · `Alt+Shift+q` fecha a janela · `Alt+f` tela cheia · `Alt+Shift+e` sai.
