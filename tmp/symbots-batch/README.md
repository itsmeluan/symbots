# Animações dos Symbots

Este conjunto contém animações de **idle** e **ataque** para os 48 PNGs encontrados em `symbots-sprites`.

## Organização

```text
symbots-animation/
  <família>/
    <nome-do-sprite>/
      idle/
        <nome-do-sprite>-idle.gif
        <nome-do-sprite>-idle-spritesheet.png
        frames/frame-01.png ... frame-06.png
      attack/
        <nome-do-sprite>-attack.gif
        <nome-do-sprite>-attack-spritesheet.png
        frames/frame-01.png ... frame-06.png
  manifest.csv
```

Cada spritesheet usa uma grade de **3 colunas × 2 linhas**, lida da esquerda para a direita na primeira linha e depois na segunda.

## Movimento

- **Idle:** oscilação mecânica vertical suave, fechando em loop.
- **Ataque:** preparação para trás, avanço rápido para a direita, recuo e retorno à pose neutra.
- **Duração:** seis frames por animação.
- **Fundo:** transparente.

## Preservação dos sprites

- Somente os PNGs foram processados; os arquivos `.aseprite` foram usados apenas para validar a integridade das fontes.
- Nenhuma peça, efeito ou detalhe visual foi desenhado novamente.
- Os pixels originais são apenas reposicionados em cada quadro.
- O conteúdo do primeiro frame de cada animação é idêntico pixel por pixel ao PNG correspondente.
- As telas das animações têm uma pequena margem transparente adicional para impedir cortes durante o ataque. Idle e ataque usam exatamente a mesma tela para cada sprite.

O arquivo `manifest.csv` relaciona cada fonte aos GIFs e spritesheets gerados e registra o resultado da validação.
