# Skills do Claude da Luma (plano, Fase 5)

Cada pasta vira um `.skill` pra instalar no claude.ai da Luma. Todas usam o conector do hub (o hub é a fonte).
Regras de todas: nunca inventar dado ou número; contrato só com o texto dela; nada interno pro cliente.

| Skill | Pra quê | Ferramentas do conector |
|---|---|---|
| `luma-rotina` | "O que tem pra hoje?", anotar decisão, criar e fechar tarefa | `visao_do_dia`, `listar_tarefas`, `salvar_tarefa`, `anotar` |
| `luma-identidade` | Design system dela (cores, fontes, logo, tom) pra qualquer material | `ver_identidade` |
| `luma-proposta` | Do lead à proposta com a cara dela, salva no CRM e move o lead | `ver_lead`, `listar_servicos`, `salvar_proposta`, `gerar_pdf_proposta` |
| `luma-contrato` | Monta o contrato do modelo dela com os dados do cliente e manda assinar | `ver_contrato`, `salvar_contrato`, `enviar_para_assinar` |
| `luma-crm` | Quem chegou, quem sumiu, mensagem de retorno pronta pra copiar | `funil`, `listar_leads`, `mover_lead`, `registrar_conversa` |
| `luma-duvidas` | Tirar dúvida do dia a dia (obra, norma, cliente) no jeito dela de falar | nenhuma (só identidade + guia de fala) |

Nota: a Luma está na conta grátis do Claude. Conector e skills dependem do que o plano dela libera. Conferir na
página oficial antes da Fase 5.
