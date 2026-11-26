-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0007 · conector do Claude + "o que tem pra hoje"
--
-- O Claude da Luma (claude.ai, com as skills dela) fala com o hub por um
-- conector MCP em /api/mcp/[codigo]. Cada pessoa tem o próprio código (só o hash
-- fica aqui). O que o Claude grava fica no histórico como "pelo Claude".
-- ════════════════════════════════════════════════════════════════════════════

create table conector_codigos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  membro_id uuid not null references membros(id) on delete cascade,
  hash text not null unique,
  ativo boolean not null default true,
  ultimo_uso_em timestamptz,
  criado_em timestamptz not null default now()
);
alter table conector_codigos enable row level security;
create policy conector_codigos_leitura on conector_codigos for select
  using (eh_membro(org_id) and membro_id in (select id from membros where user_id = auth.uid()));

-- Gera um código novo pra quem está logado (o antigo para de valer). Mostra uma vez só.
create or replace function conector_gerar(p_org uuid) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare v_membro uuid; v_codigo text := encode(gen_random_bytes(24), 'hex');
begin
  select id into v_membro from membros where org_id = p_org and user_id = auth.uid() and ativo;
  if v_membro is null then raise exception 'Sem acesso.'; end if;
  update conector_codigos set ativo = false where membro_id = v_membro;
  insert into conector_codigos (org_id, membro_id, hash) values (p_org, v_membro, encode(digest(v_codigo, 'sha256'), 'hex'));
  return v_codigo;
end; $$;

-- Usado só pelo servidor (chave de serviço) pra saber quem está do outro lado.
create or replace function conector_dono(p_codigo text, out org_id uuid, out membro_id uuid, out user_id uuid, out papel text, out nome text)
language sql security definer set search_path = public, extensions as $$
  update conector_codigos c set ultimo_uso_em = now()
  from membros m
  where c.hash = encode(digest(p_codigo, 'sha256'), 'hex') and c.ativo and m.id = c.membro_id and m.ativo
  returning c.org_id, c.membro_id, m.user_id, m.papel, m.nome;
$$;
revoke all on function conector_dono(text) from public, anon, authenticated;

-- "O que tem pra hoje?" (tela inicial do hub e pergunta mais comum pro Claude)
create or replace function visao_do_dia(p_org uuid, p_dia date default current_date) returns jsonb
language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'dia', p_dia,
    'reunioes', (select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'tipo', r.tipo, 'quando', r.quando, 'onde', r.onde,
        'com', coalesce(c.nome, l.nome), 'projeto', p.nome) order by r.quando), '[]')
      from reunioes r left join clientes c on c.id = r.cliente_id left join leads l on l.id = r.lead_id
      left join projetos p on p.id = r.projeto_id
      where r.org_id = p_org and r.quando::date = p_dia),
    'tarefas_hoje', (select coalesce(jsonb_agg(jsonb_build_object('id', t.id, 'titulo', t.titulo, 'prazo', t.prazo,
        'prioridade', t.prioridade, 'area', t.area) order by t.prioridade desc, t.prazo), '[]')
      from tarefas t where t.org_id = p_org and t.status in ('a_fazer', 'fazendo')
        and t.prazo <= p_dia
        and (t.bloqueada_por is null or exists (select 1 from tarefas b where b.id = t.bloqueada_por and b.status in ('feita', 'cancelada')))),
    'leads_novos', (select count(*) from leads l where l.org_id = p_org and l.etapa = 'novo'),
    'leads_pra_retornar', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'nome', l.nome, 'etapa', l.etapa,
        'proxima_acao', l.proxima_acao)), '[]')
      from leads l where l.org_id = p_org and l.etapa not in ('ganho', 'perdido') and l.proximo_contato <= p_dia),
    'leads_parados', (select coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'nome', l.nome, 'etapa', l.etapa,
        'dias', (p_dia - l.entrou_na_etapa_em::date))), '[]')
      from leads l join estudio e on e.org_id = l.org_id
      where l.org_id = p_org and l.etapa not in ('ganho', 'perdido') and e.dias_lead_parado is not null
        and (p_dia - l.entrou_na_etapa_em::date) >= e.dias_lead_parado),
    'projetos_em_andamento', (select count(*) from projetos p where p.org_id = p_org and p.status in ('em_andamento', 'aguardando_cliente')),
    'financeiro', case when eh_admin(p_org) then (select jsonb_build_object(
        'receber_hoje_centavos', coalesce(sum(valor_centavos) filter (where tipo = 'entrada'), 0),
        'pagar_hoje_centavos', coalesce(sum(valor_centavos) filter (where tipo = 'saida'), 0),
        'atrasados', count(*) filter (where vencimento < p_dia))
      from lancamentos where org_id = p_org and status = 'previsto' and vencimento <= p_dia) end
  ) where eh_membro(p_org);
$$;
