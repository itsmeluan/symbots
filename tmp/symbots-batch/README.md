# Animações dos Symbots

Este conjunto contém animações de **idle**, **ataque**, **dano** e **destruição** para os 48 PNGs encontrados em `symbots-sprites`.

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
      damage/
        <nome-do-sprite>-damage.gif
        <nome-do-sprite>-damage-spritesheet.png
        frames/frame-01.png ... frame-06.png
      destroyed/
        <nome-do-sprite>-destroyed.gif
        <nome-do-sprite>-destroyed.png
        <nome-do-sprite>-destroyed-spritesheet.png
        frames/frame-01.png ... frame-06.png
  manifest.csv
```

Cada spritesheet usa uma grade de **3 colunas × 2 linhas**, lida da esquerda para a direita na primeira linha e depois na segunda.

## Movimento

- **Idle:** oscilação mecânica vertical suave, fechando em loop.
- **Ataque:** preparação para trás, avanço rápido para a direita, recuo e retorno à pose neutra.
- **Dano:** recuo rápido para a esquerda, dois flashes brancos e retorno à pose neutra. No jogo, recomenda-se reproduzir esta animação uma vez por impacto.
- **Destruição:** tremor curto, perda de cor e parada completa em tons de cinza. Os GIFs são de reprodução única e permanecem no último frame; no jogo, mantenha o frame 6 após a animação. O PNG `<nome>-destroyed.png` contém exatamente esse estado final como imagem estática.
- **Duração:** seis frames por animação.
- **Fundo:** transparente.

## Preservação dos sprites

- Somente os PNGs foram processados; os arquivos `.aseprite` foram usados apenas para validar a integridade das fontes.
- Nenhuma peça, efeito ou detalhe visual foi desenhado novamente.
- Os pixels originais são apenas reposicionados em cada quadro.
- O conteúdo do primeiro frame de cada animação é idêntico pixel por pixel ao PNG correspondente.
- As telas das animações têm uma pequena margem transparente adicional para impedir cortes durante o movimento. Idle, ataque, dano e destruição usam exatamente a mesma tela para cada sprite.

O arquivo `manifest.csv` relaciona cada fonte aos GIFs e spritesheets gerados e registra o resultado da validação.
