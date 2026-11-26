-- Teste de fumaça do schema: roda depois das migrations. Para no primeiro erro.
\set ON_ERROR_STOP on

insert into auth.users values ('00000000-0000-0000-0000-00000000000a', 'luma@teste'), ('00000000-0000-0000-0000-00000000000b', 'apoio@teste');
insert into organizacoes (id, nome) values ('11111111-1111-1111-1111-111111111111', 'Luma Almeida Arquitetura');
insert into membros (org_id, user_id, nome, email, papel) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000a', 'Luma', 'luma@teste', 'admin'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-00000000000b', 'Apoio', 'apoio@teste', 'apoio');
select pre_briefing_configurar('11111111-1111-1111-1111-111111111111', 'segredo-de-teste');
insert into estudio (org_id, nome_publico) values ('11111111-1111-1111-1111-111111111111', 'Luma (teste)');

-- 0) Visitante anônimo não chama o pré-briefing direto (só a rota do servidor)
set role anon;
do $$ begin perform pre_briefing_enviar('segredo-de-teste', '{}'); raise exception 'anon chamou direto';
exception when insufficient_privilege then null; end $$;
reset role;

-- 1) Rota do servidor: abre o pré-briefing, para no meio; outro manda até o fim.
set role service_role;
select pre_briefing_passo('segredo-de-teste', 'aaaaaaaa-0000-0000-0000-000000000001', 'servico', 'hero', '{"utm_source":"instagram"}');
select pre_briefing_passo('segredo-de-teste', 'aaaaaaaa-0000-0000-0000-000000000002', 'servico', 'portfolio', null);
select pre_briefing_passo('segredo-de-teste', 'aaaaaaaa-0000-0000-0000-000000000002', 'contato', 'portfolio', null);
select pre_briefing_enviar('segredo-de-teste', '{"sessao":"aaaaaaaa-0000-0000-0000-000000000002","nome":"Cliente Teste","telefone":"(81) 99999-0000","servico":"Projeto de interiores","ambientes":["cozinha","sala"],"tem_planta":true}') is not null as lead_criado;
-- mesma pessoa de novo: não duplica
select pre_briefing_enviar('segredo-de-teste', '{"nome":"Cliente Teste","telefone":"81999990000","mensagem":"esqueci de dizer"}') is not null;
-- segredo errado é barrado
do $$ begin perform pre_briefing_enviar('errado', '{"nome":"x","telefone":"81999990000"}'); raise exception 'deveria ter barrado';
exception when others then if sqlerrm not like '%não configurado%' then raise; end if; end $$;
reset role;
set role anon;
-- anônimo não lê tabela nenhuma
do $$ begin perform 1 from leads; raise exception 'anon leu leads'; exception when insufficient_privilege then null; end $$;
select jsonb_array_length(portfolio_publico()) = 0 as portfolio_vazio;
reset role;

-- 2) Luma logada
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
set request.jwt.claim.email = 'luma@teste';
select count(*) = 1 as um_lead_so from leads;
select funil('11111111-1111-1111-1111-111111111111', current_date - 1, current_date) as funil;

insert into servicos (org_id, nome, limite_alteracoes, prazo_dias_uteis) values
  ('11111111-1111-1111-1111-111111111111', 'Projeto de interiores', null, null) returning id \gset serv_
insert into servico_etapas (org_id, servico_id, ordem, nome, reuniao_tipo) values
  ('11111111-1111-1111-1111-111111111111', :'serv_id', 1, 'Briefing e medição', 'briefing'),
  ('11111111-1111-1111-1111-111111111111', :'serv_id', 2, 'Apresentação do 3D', 'apresentacao_3d'),
  ('11111111-1111-1111-1111-111111111111', :'serv_id', 3, 'Ajustes', 'ajuste'),
  ('11111111-1111-1111-1111-111111111111', :'serv_id', 4, 'Projeto executivo', null),
  ('11111111-1111-1111-1111-111111111111', :'serv_id', 5, 'Entrega do executivo', 'entrega');

-- proposta enviada move o lead
select id as lead_id from leads limit 1 \gset
insert into propostas (org_id, lead_id, titulo, para_quem, status, valor_centavos)
  values ('11111111-1111-1111-1111-111111111111', :'lead_id', 'Cozinha e sala', 'Cliente Teste', 'enviada', 100) returning numero;
select etapa = 'proposta_enviada' as lead_andou from leads where id = :'lead_id';

-- ganhou: vira cliente e projeto com etapas e tarefas encadeadas
select ganhar_lead(:'lead_id') as cliente_id \gset
select criar_projeto('11111111-1111-1111-1111-111111111111', :'cliente_id', :'serv_id', 'Cozinha e sala', current_date, array['cozinha','sala']) as proj_id \gset
select count(*) = 5 as cinco_etapas from projeto_etapas where projeto_id = :'proj_id';
select count(*) = 5 as cinco_tarefas from tarefas where projeto_id = :'proj_id';
update projetos set limite_alteracoes = 1 where id = :'proj_id';
insert into alteracoes (org_id, projeto_id, pedido) values ('11111111-1111-1111-1111-111111111111', :'proj_id', 'trocar bancada');
insert into alteracoes (org_id, projeto_id, pedido) values ('11111111-1111-1111-1111-111111111111', :'proj_id', 'mudar cor');
select array_agg(fora_do_limite order by pedida_em, pedido) = array[true,false] as limite_ok from alteracoes; -- 'mudar cor' foi a 2ª

-- financeiro
insert into contas_fixas (org_id, nome, valor_centavos, dia_vencimento) values ('11111111-1111-1111-1111-111111111111', 'Software', 5000, 31);
select gerar_contas_do_mes('11111111-1111-1111-1111-111111111111', date '2027-02-01') = 1 as gerou;
select gerar_contas_do_mes('11111111-1111-1111-1111-111111111111', date '2027-02-01') = 0 as nao_duplica;
select vencimento = date '2027-02-28' as fev_ok from lancamentos;
insert into lancamentos (org_id, tipo, descricao, valor_centavos, vencimento, status) values ('11111111-1111-1111-1111-111111111111', 'entrada', 'Sinal', 100, current_date, 'pago');
select resumo_financeiro('11111111-1111-1111-1111-111111111111', current_date);
select jsonb_array_length(visao_do_dia('11111111-1111-1111-1111-111111111111') -> 'tarefas_hoje') = 1 as uma_tarefa_de_resposta;

-- portfólio: só aparece publicado E autorizado
insert into portfolio_projetos (org_id, slug, titulo, publicado, autorizado) values
  ('11111111-1111-1111-1111-111111111111', 'a', 'Publicado sem autorização', true, false),
  ('11111111-1111-1111-1111-111111111111', 'b', 'Ok', true, true);
reset role;

-- 3) Apoio: vê CRM, não vê dinheiro
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
select count(*) = 1 as apoio_ve_lead from leads;
select count(*) = 0 as apoio_nao_ve_financeiro from lancamentos;
select count(*) = 0 as apoio_nao_ve_proposta from propostas;
select visao_do_dia('11111111-1111-1111-1111-111111111111') -> 'financeiro' = 'null'::jsonb as apoio_sem_financeiro_no_dia;
reset role;

set role anon;
select jsonb_array_length(portfolio_publico()) = 1 as so_autorizado;
select site_publico() ->> 'nome' as site_nome;
reset role;

select count(*) > 0 as historico_gravou from auditoria;
