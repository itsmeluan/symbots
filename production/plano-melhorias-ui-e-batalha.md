# Symbots — Plano de melhorias (UI, batalha, telas e arte)

> Handoff para execução no **Claude Code** (local, no repo).
> Gerado a partir da revisão da lista do Luan + leitura do código em `src/`.
> Data: 2026-07-24. Engine: Godot 4 / GDScript.

## Como usar este documento

- A implementação (Rodadas 1–5) deve ser feita no **Claude Code**, não no Cowork:
  é um codebase Godot grande e interligado, precisa rodar o engine para validar o
  visual, tem testes GUT e hook de auto-commit no `.claude/`. O Cowork fica para
  planejamento, decisões e a Rodada 6 (arte / pixellab).
- Cada rodada é um bloco coeso. Sugestão: uma rodada por sessão/PR no Code.
- Protocolo do repo (`CLAUDE.md`): perguntar antes de escrever, mostrar draft,
  aprovação por changeset. Manter.

---

## Rodada 0 — Decisões (FECHADAS)

| # | Item | Decisão |
|---|------|---------|
| 1 | Afinidades e fraquezas | **Fica para depois.** Não existe no código hoje (há `damage_formula` e tipos de dano, mas nenhuma tabela de afinidade). Vira épico de design separado, fora deste lote. |
| 2 | Symbot pode ter > 3 skills? | **Sim (ver achado abaixo).** A árvore concede mais skills do que cabem em batalha. Não criar nada novo; rever UI para (a) listar todas as skills aprendidas e (b) deixar escolher quais 3 entram em batalha. Tratado na Rodada 4. |
| 3 | Upar symbot com Scrap / outra currency | **Novo épico de design**, pensar depois. Fora deste lote. |
| 4 | Aba de skills no workshop | **Decidir na Rodada 4** (junto do modal de abas). Lembrar o Luan de bater o martelo nesse momento. |
| 5 | Patch curar qualquer aliado | **OK — corrigir.** O motor já suporta os dois modos; ver achado abaixo. |

### Achado técnico — sistema de skills (decisão 2)

- Batalha campo por symbot: **ataque básico** (slot 0, automático) + **até 3 skills
  ativas** (`ACTIVE_SLOTS := 3` em `core/battle_v1/unit_builder.gd`) + **1 ultimate**
  (slot próprio).
- A **árvore pode conceder mais de 3 skills**: `TreeAllocator.granted_skills()` não tem
  limite de nós `ACTIVE`; somado a `species.starting_skills`, o pool aprendido passa de 3.
- Hoje `unit_builder._resolve_skills()` pega as **3 primeiras na ordem** e descarta o resto.
  Existe `SymbotInstance.active_skills = [&"", &"", &""]` (os 3 slots que o jogador
  "escolheria"), mas **ele não é lido pelo `unit_builder`** — a seleção não está conectada.
- **Conclusão:** falta uma **UI de loadout** (escolher quais 3 skills aprendidas vão para
  batalha) + ligar `active_skills` ao `unit_builder`. O teto de 3 pode ser revisto no futuro
  (constante `ACTIVE_SLOTS`), mas isso é decisão de design à parte.

### Achado técnico — cura / Patch (decisão 5)

- `core/battle_v1/skill_def.gd` já define os modos de alvo:
  - `SINGLE_ALLY` = **qualquer aliado** (escolha manual).
  - `LOWEST_HP_ALLY` = **o mais ferido** ("resolve sem pick manual").
  - `ALL_ALLIES`, `SELF`, etc.
- O bug do Patch (trava em aliado sem dano) provavelmente é `LOWEST_HP_ALLY` resolvendo por
  **HP absoluto** em vez de **HP faltante** (menor razão vida/total). Verificar em
  `core/battle_v1/targeting.gd` e no `.tres` do Patch em `assets/data/skills/`.
- Preferência do Luan: Patch cura **o com mais dano** (menor vida vs. total) →
  `LOWEST_HP_ALLY` com resolução por HP faltante. Só criar "qualquer aliado" se nenhuma
  outra skill já fizer isso (checar catálogo de `.tres`).

---

## Rodada 1 — Bugs e regras de batalha (rápido, alto impacto)

Primeiro passo: abrir `core/battle_v1/targeting.gd` (concentra taunt + resolução de alvo).

- **Remover a regra de "atacar o tank primeiro"** (provocar não faz sentido como padrão).
  Ver `targeting.gd` + flags `is_taunt_skill` / `ignores_taunt` em `skill_def.gd`. Definir se
  taunt passa a ser efeito só de skill de provocar (status) e não regra global de mira.
- **Corrigir alvo do Patch** (trava em aliado sem dano) → `targeting.gd` (`LOWEST_HP_ALLY`
  por HP faltante) + `.tres` do Patch. Confirmar se há outra skill `SINGLE_ALLY`/heal-any;
  se não houver e o Luan quiser, avaliar deixar uma como "qualquer aliado".
- **Modal "deploy squad" no mapa:** botão de fechar + reorganizar layout (vazio grande
  abaixo do botão) → `ui/squad_screen.gd` / `ui/stage_select_screen.gd`.

## Rodada 2 — Polish visual da batalha (HUD e estados)

Concentrado em `ui/battle/unit_panel.gd` e `ui/battle/battle_screen.gd`.

- Barra de vida/overload **acima** do sprite (hoje embaixo).
- **Ícones de efeitos** distintos por tipo de efeito, dispostos na **vertical, à frente**
  dos symbots. (Ver `ui/theme/skill_icons.gd` / `ui/components/icon_glyph.gd` para o padrão
  de ícones.)
- **Dessaturar (tons de cinza)** inimigos e aliados quando morrem.
- Botões de skill de baixo = **só o quadrado com o sprite** (nome e detalhes seguem no
  modal) → `ui/components/bottom_dock.gd`.
- **Estados da ultimate:** descarregada em cinza → contorno preenchendo de amarelo conforme
  carrega → carregada = borda amarela completa + sprite colorido. (Carga já existe:
  `charge_cost`/`uses_charge()` em `skill_def.gd`.)

## Rodada 3 — Telas de resultado e forja

- **Vitória / derrota** (`ui/reward_screen.gd`): mostrar sprite dos symbots; barra de XP
  com animação de preenchimento; seta de "subiu de nível" ao passar de lvl; nível acima da
  barra; XP atual e quanto falta; ícones padrão dos recursos e itens obtidos.
- **Forja** (`ui/foundry_screen.gd`): tela de sucesso mais animada (sprite crescendo e
  voltando ao tamanho normal, algum "feedback" de emoção — hoje está pobre).

## Rodada 4 — Navegação e modais de detalhe

- **Botão + gesto de voltar** nas telas que abrem da home → `ui/screen.gd` /
  `ui/home_screen.gd`.
- **Modal de detalhes do symbot com abas** → `ui/battle/unit_info_modal.gd`:
  - Abas: **Stats** / **Skills ativas** / **Passivas**. Botões de aba sempre visíveis.
  - **Acomodar a decisão 2:** listar todas as skills aprendidas (podem ser > 3) e permitir
    **escolher quais 3** entram em batalha; ligar `SymbotInstance.active_skills` ao
    `unit_builder._resolve_skills`.
  - **⚠️ LEMBRETE (decisão 4):** bater o martelo com o Luan se essa mesma UI de skills entra
    também como **aba no workshop**.
- Na **árvore**, tocar no sprite central do symbot abre esse modal →
  `ui/tree/skill_tree_screen.gd` / `ui/tree/skill_tree_view.gd`.

## Rodada 5 — Layout da Bag

- Refazer o layout da bag, com foco especial nos **blueprints** → `ui/bag_screen.gd`.

## Rodada 6 — Arte / assets (pode ser feito no Cowork)

Lote de geração de asset (pixellab), separado do código:

- Sprites para **todos os itens** (objetos).
- **Backgrounds** novos para todas as telas **exceto o workshop**.
- Sprites para **todos os menus**.

---

## Ordem sugerida de execução

1. Rodada 1 (bugs — destrava o "feel" da batalha)
2. Rodada 2 (HUD)
3. Rodada 3 (telas de resultado/forja)
4. Rodada 4 (navegação + modal de abas + loadout de skills)
5. Rodada 5 (bag)
6. Rodada 6 (arte) — em paralelo, quando quiser

Cada rodada deve terminar com verificação (testes GUT relevantes + checagem visual no
engine) antes de commitar.
