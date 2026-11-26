-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0002 · serviços, clientes, projetos, etapas, reuniões e tarefas
--
-- O jeito de trabalhar da Luma (reunião de 23/11/2026):
--   orçamento → reunião 1 (briefing + medição) → reunião 2 (3D) → ajustes
--   (cada alteração vira reunião, com limite combinado) → projeto executivo →
--   reunião 3 (entrega do executivo).
-- Isso vira MODELO de etapas por serviço. Prazos e nº de alterações não ficam
-- no código: vêm do serviço ou do projeto, digitados pela Luma.
-- ════════════════════════════════════════════════════════════════════════════

-- ─── Serviços que ela vende ─────────────────────────────────────────────────
create table servicos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  nome text not null,
  descricao_cliente text,          -- frase que vai na proposta e no site
  prazo_dias_uteis int check (prazo_dias_uteis is null or prazo_dias_uteis > 0),
  limite_alteracoes int check (limite_alteracoes is null or limite_alteracoes >= 0),
  aparece_no_site boolean not null default false,
  ativo boolean not null default true,
  ordem int not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid,
  unique (org_id, nome)
);
select preparar_tabela('servicos', 'membro');

-- Etapas padrão de cada serviço (o "passo a passo" que vira tarefas no projeto).
create table servico_etapas (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  servico_id uuid not null references servicos(id) on delete cascade,
  ordem int not null,
  nome text not null,
  tem_reuniao boolean not null default false,
  reuniao_tipo text check (reuniao_tipo is null or reuniao_tipo in
    ('briefing', 'medicao', 'apresentacao_3d', 'ajuste', 'entrega', 'vistoria', 'outra')),
  dias_uteis int check (dias_uteis is null or dias_uteis >= 0),  -- vazio = sem prazo sugerido
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid,
  unique (servico_id, ordem)
);
select preparar_tabela('servico_etapas', 'membro');

-- ─── Clientes ───────────────────────────────────────────────────────────────
create table clientes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  nome text not null,
  telefone text,
  email text,
  instagram text,
  documento text,                  -- CPF/CNPJ (vai no contrato)
  endereco text,                   -- endereço de cobrança/contrato
  cidade text,
  origem text,                     -- copiado do lead
  lead_id uuid,                    -- liga com o CRM (fk na 0003)
  observacoes text,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('clientes', 'membro');
create index clientes_org_nome on clientes (org_id, lower(nome));

-- ─── Projetos ───────────────────────────────────────────────────────────────
create table projetos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  cliente_id uuid not null references clientes(id) on delete restrict,
  servico_id uuid references servicos(id) on delete set null,
  nome text not null,              -- ex.: "Cozinha e sala · Apto 1302"
  status text not null default 'aguardando_inicio' check (status in
    ('aguardando_inicio', 'em_andamento', 'aguardando_cliente', 'pausado', 'entregue', 'cancelado')),
  tipo_imovel text check (tipo_imovel is null or tipo_imovel in
    ('apartamento', 'casa', 'comercial', 'area_externa', 'outro')),
  endereco_obra text,
  metragem_m2 numeric(8,2) check (metragem_m2 is null or metragem_m2 > 0),
  tem_planta boolean,
  medicao_conferida boolean not null default false,  -- ela insiste: conferir medida antes de executar
  limite_alteracoes int check (limite_alteracoes is null or limite_alteracoes >= 0),
  data_inicio date,
  data_entrega_prevista date,
  entregue_em date,
  pasta_url text check (pasta_url is null or pasta_url like 'https://%'),
  proposta_id uuid,                -- fk na 0004
  observacoes text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('projetos', 'membro');
create index projetos_org_status on projetos (org_id, status);
create index projetos_cliente on projetos (cliente_id);

create table projeto_ambientes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  projeto_id uuid not null references projetos(id) on delete cascade,
  nome text not null,              -- cozinha, sala, quarto do casal...
  metragem_m2 numeric(8,2) check (metragem_m2 is null or metragem_m2 > 0),
  observacoes text,
  ordem int not null default 0,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('projeto_ambientes', 'membro');

create table projeto_etapas (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  projeto_id uuid not null references projetos(id) on delete cascade,
  ordem int not null,
  nome text not null,
  status text not null default 'pendente' check (status in ('pendente', 'em_andamento', 'concluida', 'pulada')),
  previsto_para date,
  concluida_em timestamptz,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid,
  unique (projeto_id, ordem)
);
select preparar_tabela('projeto_etapas', 'membro');

-- Cada pedido de mudança do cliente. A contagem é o que vale contra o limite.
create table alteracoes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  projeto_id uuid not null references projetos(id) on delete cascade,
  fase text not null default '3d' check (fase in ('3d', 'executivo')),
  pedido text not null,
  pedida_em date not null default current_date,
  fora_do_limite boolean not null default false,  -- marcado sozinho quando passa do limite
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('alteracoes', 'membro');

create or replace function marcar_alteracao_fora_do_limite() returns trigger
language plpgsql as $$
declare v_limite int; v_qtd int;
begin
  select limite_alteracoes into v_limite from projetos where id = new.projeto_id;
  if v_limite is null then new.fora_do_limite := false; return new; end if;
  select count(*) into v_qtd from alteracoes where projeto_id = new.projeto_id and id <> new.id;
  new.fora_do_limite := v_qtd >= v_limite;
  return new;
end; $$;
create trigger alteracoes_limite before insert on alteracoes for each row execute function marcar_alteracao_fora_do_limite();

-- ─── Reuniões (com cliente ou com lead) ─────────────────────────────────────
create table reunioes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  projeto_id uuid references projetos(id) on delete cascade,
  cliente_id uuid references clientes(id) on delete cascade,
  lead_id uuid,                    -- fk na 0003
  tipo text not null check (tipo in
    ('briefing', 'medicao', 'apresentacao_3d', 'ajuste', 'entrega', 'vistoria', 'primeira_conversa', 'outra')),
  quando timestamptz not null,
  onde text,                       -- endereço ou link
  notas text,
  aconteceu boolean,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('reunioes', 'membro');
create index reunioes_org_quando on reunioes (org_id, quando);

-- ─── Tarefas ────────────────────────────────────────────────────────────────
create table tarefas (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  titulo text not null,
  descricao text,
  status text not null default 'a_fazer' check (status in ('a_fazer', 'fazendo', 'feita', 'cancelada')),
  prioridade text not null default 'normal' check (prioridade in ('normal', 'urgente')),
  prazo date,
  projeto_id uuid references projetos(id) on delete cascade,
  etapa_id uuid references projeto_etapas(id) on delete set null,
  cliente_id uuid references clientes(id) on delete set null,
  lead_id uuid,                    -- fk na 0003
  area text not null default 'projeto' check (area in ('projeto', 'comercial', 'financeiro', 'conteudo', 'pessoal', 'outra')),
  bloqueada_por uuid references tarefas(id) on delete set null,
  concluida_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('tarefas', 'membro');
create index tarefas_org_status_prazo on tarefas (org_id, status, prazo);

create or replace function tarefa_concluida_em() returns trigger
language plpgsql as $$
begin
  if new.status = 'feita' and (tg_op = 'INSERT' or old.status <> 'feita') then new.concluida_em := now();
  elsif new.status <> 'feita' then new.concluida_em := null;
  end if;
  return new;
end; $$;
create trigger tarefas_concluida before insert or update on tarefas for each row execute function tarefa_concluida_em();

-- ─── Dia útil (seg a sex; feriados entram depois, se a Luma quiser) ─────────
create or replace function somar_dias_uteis(p_inicio date, p_dias int) returns date
language plpgsql immutable as $$
declare d date := p_inicio; n int := 0;
begin
  if p_dias is null then return null; end if;
  while n < p_dias loop
    d := d + 1;
    if extract(isodow from d) < 6 then n := n + 1; end if;
  end loop;
  return d;
end; $$;

-- ─── Criar projeto a partir do serviço ──────────────────────────────────────
-- Copia as etapas do serviço, distribui as datas (só se a etapa tiver dias) e
-- cria uma tarefa por etapa, cada uma esperando a anterior.
create or replace function criar_projeto(
  p_org uuid, p_cliente uuid, p_servico uuid, p_nome text, p_inicio date default null,
  p_ambientes text[] default null
) returns uuid
language plpgsql security invoker set search_path = public as $$
declare
  v_proj uuid; v_serv servicos; e record; v_data date; v_etapa uuid; v_tarefa uuid; v_anterior uuid;
  v_amb text; v_i int := 0;
begin
  if not eh_membro(p_org) then raise exception 'Sem acesso.'; end if;
  select * into v_serv from servicos where id = p_servico and org_id = p_org;
  insert into projetos (org_id, cliente_id, servico_id, nome, data_inicio, limite_alteracoes, status)
  values (p_org, p_cliente, p_servico, p_nome, p_inicio, v_serv.limite_alteracoes,
          case when p_inicio is null then 'aguardando_inicio' else 'em_andamento' end)
  returning id into v_proj;

  if p_ambientes is not null then
    foreach v_amb in array p_ambientes loop
      v_i := v_i + 1;
      insert into projeto_ambientes (org_id, projeto_id, nome, ordem) values (p_org, v_proj, v_amb, v_i);
    end loop;
  end if;

  v_data := p_inicio;
  for e in select * from servico_etapas where servico_id = p_servico order by ordem loop
    v_data := case when v_data is null or e.dias_uteis is null then null else somar_dias_uteis(v_data, e.dias_uteis) end;
    insert into projeto_etapas (org_id, projeto_id, ordem, nome, previsto_para)
    values (p_org, v_proj, e.ordem, e.nome, v_data) returning id into v_etapa;
    insert into tarefas (org_id, titulo, projeto_id, etapa_id, cliente_id, prazo, bloqueada_por, area)
    values (p_org, p_nome || ' · ' || e.nome, v_proj, v_etapa, p_cliente, v_data, v_anterior, 'projeto')
    returning id into v_tarefa;
    v_anterior := v_tarefa;
  end loop;

  if v_serv.prazo_dias_uteis is not null and p_inicio is not null then
    update projetos set data_entrega_prevista = somar_dias_uteis(p_inicio, v_serv.prazo_dias_uteis) where id = v_proj;
  end if;
  return v_proj;
end; $$;
