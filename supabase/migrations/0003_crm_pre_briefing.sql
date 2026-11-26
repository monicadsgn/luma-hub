-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0003 · CRM (funil de leads) + entrada pública do pré-briefing
--
-- Todo botão do site leva ao pré-briefing. Quem preenche vira lead aqui.
-- "Quem chegou e quem não chegou":
--   • pre_briefing_visitas → cada pessoa que abriu o pré-briefing e até onde foi
--     (abriu e não mandou = não chegou);
--   • leads → quem mandou, em que etapa está e há quantos dias está parado.
--
-- Segurança (mesmo padrão do quiz do Aden): a página é pública, então as funções
-- exigem um SEGREDO que só a rota /api/pre-briefing conhece (aqui só o hash).
-- Limite por hora por visitante (hash do IP, nunca o IP). Ninguém escreve direto
-- nessas tabelas pela API pública.
-- ════════════════════════════════════════════════════════════════════════════

create table leads (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  nome text not null,
  telefone text,
  email text,
  instagram text,
  cidade text,
  origem text not null default 'outro' check (origem in
    ('site', 'instagram', 'loja', 'indicacao', 'whatsapp', 'outro')),
  como_conheceu text,              -- texto livre do formulário
  botao_origem text,               -- qual botão do site a pessoa clicou
  campanha jsonb,                  -- utm_source, utm_campaign... (vale a primeira)
  servico_id uuid references servicos(id) on delete set null,
  servico_texto text,              -- o que a pessoa escreveu/escolheu
  tipo_imovel text,
  ambientes text[],
  metragem_m2 numeric(8,2),
  tem_planta boolean,
  quando_comecar text,             -- resposta do formulário, como veio
  faixa_investimento text,         -- resposta do formulário, como veio (rótulo, não número)
  mensagem text,
  respostas jsonb,                 -- o pré-briefing inteiro, como veio
  etapa text not null default 'novo' check (etapa in
    ('novo', 'em_conversa', 'reuniao_marcada', 'proposta_enviada', 'ganho', 'perdido')),
  entrou_na_etapa_em timestamptz not null default now(),
  valor_estimado_centavos bigint check (valor_estimado_centavos is null or valor_estimado_centavos >= 0),
  proximo_contato date,
  proxima_acao text,
  motivo_perda text,
  cliente_id uuid references clientes(id) on delete set null,
  visita_id uuid,
  criado_em timestamptz not null default now(),
  fechado_em timestamptz,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('leads', 'membro');
create index leads_org_etapa on leads (org_id, etapa);
create index leads_telefone on leads (org_id, regexp_replace(coalesce(telefone, ''), '\D', '', 'g'));

alter table clientes add constraint clientes_lead_fk foreign key (lead_id) references leads(id) on delete set null;
alter table reunioes add constraint reunioes_lead_fk foreign key (lead_id) references leads(id) on delete cascade;
alter table tarefas add constraint tarefas_lead_fk foreign key (lead_id) references leads(id) on delete cascade;

create or replace function lead_mudou_etapa() returns trigger
language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.etapa is distinct from old.etapa then
    new.entrou_na_etapa_em := now();
    new.fechado_em := case when new.etapa in ('ganho', 'perdido') then now() else null end;
  end if;
  return new;
end; $$;
create trigger leads_etapa before update on leads for each row execute function lead_mudou_etapa();

create table lead_interacoes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  lead_id uuid not null references leads(id) on delete cascade,
  tipo text not null default 'nota' check (tipo in
    ('nota', 'whatsapp', 'ligacao', 'reuniao', 'email', 'proposta', 'sistema')),
  texto text not null,
  em timestamptz not null default now(),
  autor_nome text,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('lead_interacoes', 'membro');
create index lead_interacoes_lead on lead_interacoes (lead_id, em desc);

-- ─── Quem abriu o pré-briefing e até onde foi ───────────────────────────────
-- Sem auditar() de propósito: seriam muitas linhas anônimas no histórico.
create table pre_briefing_visitas (
  sessao uuid primary key,
  org_id uuid not null references organizacoes(id) on delete cascade,
  botao_origem text,
  campanha jsonb,
  passos text[] not null default '{}',
  ultimo_passo text,
  enviou boolean not null default false,
  lead_id uuid references leads(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
alter table pre_briefing_visitas enable row level security;
create policy pre_briefing_visitas_leitura on pre_briefing_visitas for select using (eh_membro(org_id));
create index pre_briefing_visitas_org on pre_briefing_visitas (org_id, criado_em desc);

create table pre_briefing_config (
  id boolean primary key default true check (id),
  org_id uuid not null references organizacoes(id) on delete cascade,
  segredo_hash text not null,
  atualizado_em timestamptz not null default now()
);
alter table pre_briefing_config enable row level security; -- sem política: só as funções leem

create table pre_briefing_limite (
  chave text not null,
  tipo text not null,
  hora timestamptz not null,
  qtd int not null default 0,
  primary key (chave, tipo, hora)
);
alter table pre_briefing_limite enable row level security;

create or replace function pre_briefing_org(p_segredo text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare v_org uuid;
begin
  select org_id into v_org from pre_briefing_config
  where segredo_hash = encode(digest(coalesce(p_segredo, ''), 'sha256'), 'hex');
  if v_org is null then raise exception 'Pré-briefing não configurado.'; end if;
  return v_org;
end; $$;

-- Liga o pré-briefing (rodar uma vez, pelo SQL Editor, com o mesmo valor da variável PRE_BRIEFING_SEGREDO).
create or replace function pre_briefing_configurar(p_org uuid, p_segredo text) returns void
language sql security definer set search_path = public, extensions as $$
  insert into pre_briefing_config (id, org_id, segredo_hash)
  values (true, p_org, encode(digest(p_segredo, 'sha256'), 'hex'))
  on conflict (id) do update set org_id = excluded.org_id, segredo_hash = excluded.segredo_hash, atualizado_em = now();
$$;

create or replace function pre_briefing_limite_checar(p_segredo text, p_chave text, p_tipo text, p_max int) returns void
language plpgsql security definer set search_path = public as $$
declare v_qtd int; v_hora timestamptz := date_trunc('hour', now());
begin
  perform pre_briefing_org(p_segredo);
  insert into pre_briefing_limite (chave, tipo, hora, qtd) values (p_chave, p_tipo, v_hora, 1)
  on conflict (chave, tipo, hora) do update set qtd = pre_briefing_limite.qtd + 1
  returning qtd into v_qtd;
  delete from pre_briefing_limite where hora < now() - interval '1 day';
  if v_qtd > p_max then raise exception 'Muitas tentativas. Tente de novo daqui a pouco.'; end if;
end; $$;

create or replace function pre_briefing_passo(p_segredo text, p_sessao uuid, p_passo text, p_botao text, p_campanha jsonb)
returns void
language plpgsql security definer set search_path = public as $$
declare v_org uuid := pre_briefing_org(p_segredo);
begin
  if p_sessao is null or length(coalesce(p_passo, '')) not between 1 and 40 then raise exception 'Pedido inválido.'; end if;
  insert into pre_briefing_visitas (sessao, org_id, botao_origem, campanha, passos, ultimo_passo)
  values (p_sessao, v_org, left(p_botao, 60), p_campanha, array[p_passo], p_passo)
  on conflict (sessao) do update set
    passos = case when p_passo = any(pre_briefing_visitas.passos) then pre_briefing_visitas.passos
                  else pre_briefing_visitas.passos || p_passo end,
    ultimo_passo = p_passo, atualizado_em = now();
end; $$;

-- Recebe o pré-briefing. Mesma pessoa (mesmo telefone) em até 7 dias atualiza
-- o lead em aberto em vez de duplicar.
create or replace function pre_briefing_enviar(p_segredo text, p_dados jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org uuid := pre_briefing_org(p_segredo);
  v_nome text := nullif(trim(p_dados ->> 'nome'), '');
  v_tel text := nullif(trim(p_dados ->> 'telefone'), '');
  v_tel_num text := regexp_replace(coalesce(p_dados ->> 'telefone', ''), '\D', '', 'g');
  v_sessao uuid := nullif(p_dados ->> 'sessao', '')::uuid;
  v_servico uuid;
  v_lead uuid;
begin
  if v_nome is null then raise exception 'Informe seu nome.'; end if;
  if length(v_tel_num) < 10 then raise exception 'Informe um WhatsApp com DDD.'; end if;
  if length(p_dados::text) > 20000 then raise exception 'Pedido inválido.'; end if;

  select id into v_servico from servicos
  where org_id = v_org and ativo and lower(nome) = lower(p_dados ->> 'servico') limit 1;

  select id into v_lead from leads
  where org_id = v_org and etapa not in ('ganho', 'perdido')
    and regexp_replace(coalesce(telefone, ''), '\D', '', 'g') = v_tel_num
    and criado_em > now() - interval '7 days'
  order by criado_em desc limit 1;

  if v_lead is null then
    insert into leads (org_id, nome, telefone, email, instagram, cidade, origem, como_conheceu, botao_origem,
      campanha, servico_id, servico_texto, tipo_imovel, ambientes, metragem_m2, tem_planta, quando_comecar,
      faixa_investimento, mensagem, respostas, visita_id)
    values (v_org, left(v_nome, 120), left(v_tel, 30), left(p_dados ->> 'email', 160), left(p_dados ->> 'instagram', 60),
      left(p_dados ->> 'cidade', 80), 'site', left(p_dados ->> 'como_conheceu', 200), left(p_dados ->> 'botao', 60),
      p_dados -> 'campanha', v_servico, left(p_dados ->> 'servico', 120), left(p_dados ->> 'tipo_imovel', 40),
      (select array_agg(left(x, 60)) from jsonb_array_elements_text(coalesce(p_dados -> 'ambientes', '[]')) x),
      nullif(p_dados ->> 'metragem_m2', '')::numeric, (p_dados ->> 'tem_planta')::boolean,
      left(p_dados ->> 'quando_comecar', 80), left(p_dados ->> 'faixa_investimento', 80),
      left(p_dados ->> 'mensagem', 2000), p_dados, v_sessao)
    returning id into v_lead;
    insert into lead_interacoes (org_id, lead_id, tipo, texto, autor_nome)
    values (v_org, v_lead, 'sistema', 'Chegou pelo pré-briefing do site.', 'Site');
    -- tarefa pra Luma responder (só no lead novo)
    insert into tarefas (org_id, titulo, lead_id, area, prazo)
    values (v_org, 'Responder ' || v_nome || ' (pré-briefing do site)', v_lead, 'comercial', current_date);
  else
    update leads set respostas = p_dados, mensagem = coalesce(left(p_dados ->> 'mensagem', 2000), mensagem),
      servico_texto = coalesce(left(p_dados ->> 'servico', 120), servico_texto)
    where id = v_lead;
    insert into lead_interacoes (org_id, lead_id, tipo, texto, autor_nome)
    values (v_org, v_lead, 'sistema', 'Mandou o pré-briefing de novo (respostas atualizadas).', 'Site');
  end if;

  if v_sessao is not null then
    update pre_briefing_visitas set enviou = true, lead_id = v_lead, atualizado_em = now() where sessao = v_sessao;
  end if;

  return v_lead;
end; $$;

revoke all on function pre_briefing_org(text) from public;
revoke all on function pre_briefing_configurar(uuid, text) from public;

-- ─── Lead virou cliente ─────────────────────────────────────────────────────
create or replace function ganhar_lead(p_lead uuid) returns uuid
language plpgsql security invoker set search_path = public as $$
declare l leads; v_cliente uuid;
begin
  select * into l from leads where id = p_lead;
  if l.id is null or not eh_membro(l.org_id) then raise exception 'Lead não encontrado.'; end if;
  if l.cliente_id is not null then return l.cliente_id; end if;
  insert into clientes (org_id, nome, telefone, email, instagram, cidade, origem, lead_id)
  values (l.org_id, l.nome, l.telefone, l.email, l.instagram, l.cidade, l.origem, l.id)
  returning id into v_cliente;
  update leads set etapa = 'ganho', cliente_id = v_cliente where id = p_lead;
  return v_cliente;
end; $$;

-- ─── Funil de um período (o painel do CRM lê daqui) ─────────────────────────
create or replace function funil(p_org uuid, p_de date, p_ate date) returns jsonb
language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'abriram_pre_briefing', (select count(*) from pre_briefing_visitas v where v.org_id = p_org and v.criado_em::date between p_de and p_ate),
    'nao_terminaram', (select count(*) from pre_briefing_visitas v where v.org_id = p_org and not v.enviou and v.criado_em::date between p_de and p_ate),
    'onde_pararam', (select coalesce(jsonb_object_agg(ultimo_passo, n), '{}') from (
        select ultimo_passo, count(*) n from pre_briefing_visitas v
        where v.org_id = p_org and not v.enviou and v.criado_em::date between p_de and p_ate group by 1) x),
    'leads_novos', (select count(*) from leads l where l.org_id = p_org and l.criado_em::date between p_de and p_ate),
    'por_origem', (select coalesce(jsonb_object_agg(origem, n), '{}') from (
        select origem, count(*) n from leads l where l.org_id = p_org and l.criado_em::date between p_de and p_ate group by 1) x),
    'por_etapa', (select coalesce(jsonb_object_agg(etapa, n), '{}') from (
        select etapa, count(*) n from leads l where l.org_id = p_org and l.criado_em::date between p_de and p_ate group by 1) x),
    'ganhos', (select count(*) from leads l where l.org_id = p_org and l.etapa = 'ganho' and l.fechado_em::date between p_de and p_ate)
  ) where eh_membro(p_org);
$$;
