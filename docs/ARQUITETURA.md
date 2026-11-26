# Arquitetura: Hub da Luma

Decisões de 26/11/2026. Base: o esqueleto do Aden (Next.js + Supabase + conector MCP + skills), adaptado pra
uma arquiteta autônoma. Não é agência: não tem sócio, divisão de horas, piso, calendário de posts nem painel de
aprovação de peças.

## Stack
| Parte | Escolha | Por quê |
|---|---|---|
| App | Next.js 16 (App Router), React 19, TypeScript, Tailwind 4 | Mesmo do Aden e do SoftMoni. Moni já conhece, reaproveita padrão de tela e de MCP. |
| Banco, login, arquivos | Supabase (Postgres + Auth + Storage), região São Paulo | RLS faz a segurança no banco. Fotos do portfólio e PDFs no Storage. |
| Hospedagem | Vercel | Mesmo fluxo dos outros sistemas. |
| Claude | Conector MCP em `/api/mcp/[codigo]` + skills | Igual ao Aden: o Claude da Luma opera o hub como ela. |

## Um app, três portas
Um projeto só, um deploy só:
- **Site público** (`/`, `/projetos/[slug]`, `/pre-briefing`): portfólio. Todo botão leva ao pré-briefing.
- **Hub** (`/hoje`, `/crm`, `/clientes`, `/projetos`, `/tarefas`, `/financeiro`, `/ajustes`): com login.
- **APIs**: `/api/pre-briefing` (entrada pública, com segredo), `/api/mcp/[codigo]` (Claude).

Motivo: lead do site cai direto no CRM sem integração entre dois sistemas, e a Luma tem um endereço só.
Se depois o site precisar de domínio próprio e o hub de outro (ex.: `app.`), é só configuração na Vercel.

## Dados (migrations em `supabase/migrations/`)
| Migration | O que tem |
|---|---|
| 0001 núcleo | organização, membros (`admin` = Luma, `apoio` = quem ajuda, sem ver dinheiro), histórico automático, dados do escritório, identidade da marca, anotações (memória) |
| 0002 trabalho | serviços com etapas padrão, clientes, projetos, ambientes, etapas do projeto, alterações (conta contra o limite), reuniões, tarefas encadeadas. `criar_projeto()` monta etapas e tarefas a partir do serviço |
| 0003 CRM | leads (funil: novo, em conversa, reunião marcada, proposta enviada, ganho, perdido), conversas, visitas do pré-briefing (quem abriu e onde parou), entrada pública com segredo e limite por hora, `ganhar_lead()`, `funil()` |
| 0004 propostas e contratos | modelos de documento (texto dela), propostas numeradas com itens, cópia congelada no envio, link público, contratos. Proposta enviada move o lead sozinha |
| 0005 financeiro | categorias, contas fixas (gera o mês sem duplicar), lançamentos com parcela, `resumo_financeiro()` |
| 0006 portfólio | projetos do portfólio e fotos. Só aparece publicado **e** autorizado. Site lê por `portfolio_publico()` e `site_publico()` |
| 0007 Claude e dia | código pessoal do conector (só hash), `visao_do_dia()` pro "o que tem pra hoje?" |

### Como o jeito dela de trabalhar virou dado
Ela contou (23/11): orçamento → reunião 1 (briefing e medição) → reunião 2 (3D) → ajustes (cada um vira reunião,
com limite) → executivo → reunião 3 (entrega). Isso é o modelo de etapas do serviço (`servico_etapas`). Ao criar
um projeto, cada etapa vira uma tarefa que só aparece quando a anterior fecha. O limite de alterações vem do
serviço e pode mudar por projeto; a alteração que passa do limite fica marcada. `medicao_conferida` existe porque
ela repetiu que a medida tem que ser conferida antes de executar.

### "Quem chegou e quem não chegou"
- Abriu o pré-briefing e não mandou: `pre_briefing_visitas` com `enviou = false` e o último passo.
- Mandou: vira lead (origem `site`, botão que clicou, UTM). Mesma pessoa em 7 dias não duplica.
- Parado: lead há N dias na mesma etapa (N = `estudio.dias_lead_parado`, ela define).
- Tudo junto: `funil(org, de, ate)`.

## Segurança
- RLS em todas as tabelas. Dinheiro (propostas, contratos, financeiro, modelos) só `admin`.
- Visitante sem login não lê tabela nenhuma. Só funções com saída controlada.
- Pré-briefing exige segredo da rota (variável `PRE_BRIEFING_SEGREDO`, só o hash no banco), limite por hora por
  visitante (hash do IP) e validação de tamanho.
- Conector do Claude: código pessoal, só o hash no banco, gerado de novo invalida o anterior.

## Testes
`scripts/testar_schema.sh` sobe as migrations num Postgres limpo e testa: pré-briefing anônimo (cria lead, não
duplica, segredo errado barrado, anônimo não lê tabela), funil, proposta movendo o lead, lead virando cliente,
projeto com etapas e tarefas, limite de alterações, contas fixas sem duplicar (fevereiro com dia 31), resumo
financeiro, visão do dia, portfólio só autorizado, e o papel `apoio` sem ver dinheiro. Último resultado: tudo ok.
