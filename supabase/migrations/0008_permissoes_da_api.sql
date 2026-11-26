-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0008 · o que a API pode alcançar
--
-- O projeto foi criado com "Grant API access to new tables automatically"
-- DESLIGADO. Então nada fica exposto por padrão: liberamos aqui, por escrito.
--   • authenticated (quem fez login): tabelas do hub. Quem vê o quê continua
--     sendo decidido pelo RLS (admin x apoio).
--   • anon (visitante do site): NENHUMA tabela. Só as funções públicas do site.
--   • tabelas internas do pré-briefing (config, limite): ninguém de fora.
-- ════════════════════════════════════════════════════════════════════════════

grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on pre_briefing_config, pre_briefing_limite from anon, authenticated;
revoke insert, update, delete on auditoria, pre_briefing_visitas, conector_codigos from authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Funções: por padrão o Postgres deixa qualquer um executar. Fechamos tudo e abrimos o que precisa.
revoke execute on all functions in schema public from public, anon, authenticated;

-- usadas pelo RLS e pelos gatilhos (precisam rodar para quem está logado)
grant execute on function eh_membro(uuid), eh_admin(uuid), somar_dias_uteis(date, int) to authenticated;
grant execute on function auditar(), carimbar(), marcar_alteracao_fora_do_limite(), tarefa_concluida_em(),
  lead_mudou_etapa(), proposta_numero(), proposta_mexe_no_lead(), lancamento_pago() to authenticated;

-- telas do hub
grant execute on function criar_projeto(uuid, uuid, uuid, text, date, text[]), ganhar_lead(uuid),
  funil(uuid, date, date), gerar_contas_do_mes(uuid, date), resumo_financeiro(uuid, date),
  visao_do_dia(uuid, date), conector_gerar(uuid) to authenticated;

-- site público (sem login)
grant execute on function portfolio_publico(), site_publico() to anon, authenticated;

-- pré-briefing: só pela rota do servidor (chave de serviço), que também passa o segredo
grant execute on function pre_briefing_passo(text, uuid, text, text, jsonb), pre_briefing_enviar(text, jsonb),
  pre_briefing_limite_checar(text, text, text, int) to service_role;

-- tabelas futuras: nascem fechadas; cada migration nova libera o que for dela
alter default privileges in schema public revoke execute on functions from public;
