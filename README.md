# Hub da Luma

Sistema da Luma Almeida, arquiteta: um lugar só pra organizar clientes, projetos, tarefas, financeiro e
comercial, com o site/portfólio ligado ao CRM e um conector pro Claude.

- Regras do projeto: `CLAUDE.md`
- Arquitetura e decisões: `docs/ARQUITETURA.md`
- Fases e pendências: `docs/ROADMAP.md`
- Skills do Claude (plano): `skills/README.md`

## Estado
Fase 1 (base de dados) pronta e testada. Telas ainda não começaram.

## Testar o schema
Precisa de um Postgres local (16+):
```
PGHOST=... PGPORT=... PGUSER=postgres scripts/testar_schema.sh
```
