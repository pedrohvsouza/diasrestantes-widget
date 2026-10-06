# Dias Restantes

> [!WARNING]
> **Projeto vibe-coded.** Todo o código foi gerado por IA (Claude) e não foi
> revisado linha a linha. Funciona no meu Plasma 6, mas use por sua conta e risco.

Widget (plasmoide) do KDE Plasma 6 que mostra quantos dias faltam para provas e
outros compromissos.

Roda **dentro do `plasmashell`** — não cria processo próprio, não abre janela e
não consome RAM adicional mensurável. O único trabalho periódico é recalcular a
diferença de dias, agendado para a próxima meia-noite (com um teto de 10 minutos
para sobreviver a suspend/resume), então o uso de CPU é essencialmente zero.

Como faz parte do Plasma, **inicia junto com a sessão automaticamente** — não
precisa de entrada em `~/.config/autostart`.

## Instalação

```sh
./install.sh --restart
```

Depois: clique com o botão direito na área de trabalho → **Adicionar widgets…** →
procure por **Dias Restantes** → arraste para a área de trabalho ou para o painel.

## Uso

Clique em **Editar datas…** (ou botão direito no widget → *Configurar Dias
Restantes…*) e cadastre os compromissos no formato `DD/MM/AAAA`.

- **Na área de trabalho:** mostra o próximo compromisso em destaque e a lista dos
  demais.
- **No painel:** mostra o nome e a contagem do próximo compromisso; o resto
  aparece ao passar o mouse ou ao clicar.
- A contagem fica **vermelha** quando faltam N dias ou menos (padrão: 7,
  configurável).
- Para tirar o fundo do widget na área de trabalho: botão direito → *Configurar…*
  → *Aparência* → desmarcar *Mostrar plano de fundo*.

## Estrutura

```
package/
  metadata.json                  identificação do plasmoide
  contents/
    config/main.xml              entradas de configuração (KConfig XT)
    config/config.qml            páginas do diálogo de configuração
    ui/main.qml                  widget (painel + área de trabalho)
    ui/configGeneral.qml         editor de compromissos
```

As datas ficam em `~/.config/plasma-org.kde.plasma.desktop-appletsrc`, na entrada
`eventsJson` do applet, como JSON: `[{"name":"...","date":"AAAA-MM-DD"}]`.

## Desenvolvimento

Para testar sem reiniciar o `plasmashell` (requer o pacote `plasma-sdk`):

```sh
sudo apt install plasma-sdk
./install.sh && plasmoidviewer -a diasrestantes
```

## Licença

MIT — veja [LICENSE](LICENSE).
