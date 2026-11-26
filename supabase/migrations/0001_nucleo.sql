-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0001 · núcleo (organização, acessos, histórico, estúdio, marca, memória)
--
-- Projeto Supabase EXCLUSIVO da Luma. Nada aqui é compartilhado com o SoftMoni,
-- com o Aden ou com a Mônica Design. Eles serviram só de referência de padrão.
--
-- Convenções (iguais às do Aden):
--   • dinheiro em centavos (bigint); percentuais de 0 a 100
--   • nenhum número de negócio tem valor padrão: preço, prazo, nº de alterações
--     e afins nascem vazios (null) e vêm do que a Luma digitar
--   • toda tabela tem org_id e RLS
--   • toda alteração vai para `auditoria` por trigger (carimbar + auditar)
-- ════════════════════════════════════════════════════════════════════════════

create extension if not exists pgcrypto;

-- ─── Organização e acessos ──────────────────────────────────────────────────
create table organizacoes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  criado_em timestamptz not null default now()
);

-- Papéis:
--   admin  → a Luma. Vê e muda tudo, inclusive financeiro.
--   apoio  → quem ajuda (ex.: Moni durante o acompanhamento). Vê CRM, projetos,
--            tarefas e portfólio. NÃO vê financeiro nem valores de proposta.
create table membros (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  nome text not null,
  email text not null,
  papel text not null check (papel in ('admin', 'apoio')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  unique (org_id, user_id)
);
alter table membros enable row level security;

create or replace function eh_membro(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros m
    where m.org_id = org and m.user_id = auth.uid() and m.ativo);
$$;

create or replace function eh_admin(org uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from membros m
    where m.org_id = org and m.user_id = auth.uid() and m.ativo and m.papel = 'admin');
$$;

create policy membros_leitura on membros for select using (eh_membro(org_id));
create policy membros_escrita on membros for all using (eh_admin(org_id)) with check (eh_admin(org_id));
alter table organizacoes enable row level security;
create policy organizacoes_leitura on organizacoes for select using (eh_membro(id));

-- ─── Histórico (nada some sem rastro) ───────────────────────────────────────
create table auditoria (
  id bigserial primary key,
  org_id uuid not null references organizacoes(id) on delete cascade,
  tabela text not null,
  registro_id text not null,
  acao text not null check (acao in ('criou', 'alterou', 'removeu')),
  antes jsonb,
  depois jsonb,
  autor_id uuid,
  autor_email text,
  pelo_claude boolean not null default false,
  em timestamptz not null default now()
);
alter table auditoria enable row level security;
create index auditoria_org_em on auditoria (org_id, em desc);
create policy auditoria_leitura on auditoria for select using (eh_admin(org_id));

create or replace function auditar() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_antes jsonb; v_depois jsonb; v_org uuid; v_id text;
begin
  if tg_op = 'DELETE' then v_antes := to_jsonb(old);
  elsif tg_op = 'UPDATE' then
    v_antes := to_jsonb(old); v_depois := to_jsonb(new);
    if (v_antes - 'atualizado_em' - 'atualizado_por') = (v_depois - 'atualizado_em' - 'atualizado_por') then
      return new;
    end if;
  else v_depois := to_jsonb(new);
  end if;
  v_org := coalesce(v_depois ->> 'org_id', v_antes ->> 'org_id')::uuid;
  v_id := coalesce(v_depois ->> 'id', v_antes ->> 'id', v_org::text);
  insert into auditoria (org_id, tabela, registro_id, acao, antes, depois, autor_id, autor_email, pelo_claude)
  values (v_org, tg_table_name, v_id,
    case tg_op when 'INSERT' then 'criou' when 'UPDATE' then 'alterou' else 'removeu' end,
    v_antes, v_depois, auth.uid(), auth.jwt() ->> 'email',
    coalesce(current_setting('luma.pelo_claude', true), '') = 'sim');
  return coalesce(new, old);
end; $$;

create or replace function carimbar() returns trigger
language plpgsql as $$
begin
  new.atualizado_em := now();
  new.atualizado_por := auth.uid();
  return new;
end; $$;

-- Liga carimbo + histórico + RLS padrão numa tabela. Uso: select preparar_tabela('clientes', 'membro');
--   leitura 'membro' → admin e apoio leem; 'admin' → só a Luma lê.
--   escrita é sempre de membro ativo, a menos que leitura seja 'admin'.
create or replace function preparar_tabela(p_tabela text, p_leitura text default 'membro') returns void
language plpgsql as $$
declare v_fn text := case p_leitura when 'admin' then 'eh_admin' else 'eh_membro' end;
begin
  execute format('alter table %I enable row level security', p_tabela);
  execute format('create trigger %I before update on %I for each row execute function carimbar()', p_tabela || '_carimbo', p_tabela);
  execute format('create trigger %I after insert or update or delete on %I for each row execute function auditar()', p_tabela || '_historico', p_tabela);
  execute format('create policy %I on %I for select using (%s(org_id))', p_tabela || '_leitura', p_tabela, v_fn);
  execute format('create policy %I on %I for all using (%s(org_id)) with check (%s(org_id))', p_tabela || '_escrita', p_tabela, v_fn, v_fn);
end; $$;

-- ─── Dados do escritório (vão na proposta, no contrato e no site) ───────────
-- Tudo nasce vazio. Só entra o que a Luma informar.
create table estudio (
  org_id uuid primary key references organizacoes(id) on delete cascade,
  nome_publico text,              -- como aparece no site e nos documentos
  nome_contrato text,             -- nome completo ou razão social no contrato
  documento text,                 -- CPF ou CNPJ
  registro_cau text,
  endereco text,
  cidade text,
  whatsapp text,
  email text,
  instagram text,
  pix text,
  validade_proposta_dias int check (validade_proposta_dias is null or validade_proposta_dias > 0),
  dias_lead_parado int check (dias_lead_parado is null or dias_lead_parado > 0),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('estudio', 'membro');

-- ─── Identidade da marca (fonte única pro site, PDFs e skills do Claude) ────
create table identidade_marca (
  org_id uuid primary key references organizacoes(id) on delete cascade,
  cores jsonb,                    -- ex.: [{"nome":"Areia","hex":"#c0a793"}]
  fonte_titulo text,
  fonte_texto text,
  logo_url text,
  logo_claro_url text,
  tom_de_voz text,                -- resumo do guia de fala
  palavras_evitar text[],
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('identidade_marca', 'membro');

-- ─── Memória (decisões, preferências e pendências de cliente, lead ou projeto)
-- Nada se apaga: o que deixou de valer é marcado como resolvido.
create table anotacoes (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  sobre text not null check (sobre in ('cliente', 'lead', 'projeto', 'geral')),
  sobre_id uuid,
  tipo text not null check (tipo in ('decisao', 'preferencia', 'pendencia', 'nota')),
  texto text not null,
  resolvida boolean not null default false,
  autor_nome text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('anotacoes', 'membro');
create index anotacoes_sobre on anotacoes (org_id, sobre, sobre_id) where not resolvida;
