-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0004 · propostas e contratos
--
-- A Luma disse que precisa de um contrato melhor e de proposta com a cara dela.
-- Regras:
--   • o TEXTO do contrato (cláusulas) é dela: vem de modelos_documento, que só a
--     Luma preenche. O sistema e o Claude nunca escrevem cláusula por conta própria.
--   • preço sempre digitado pela Luma. Nada de tabela de preço no código.
--   • proposta e contrato guardam uma cópia congelada do que foi enviado
--     (conteudo_enviado), pra nada mudar depois sem rastro.
--   • só a Luma (admin) vê valores. Quem é "apoio" não lê esta parte.
-- ════════════════════════════════════════════════════════════════════════════

create table modelos_documento (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  tipo text not null check (tipo in ('proposta', 'contrato', 'mensagem')),
  nome text not null,
  servico_id uuid references servicos(id) on delete set null,  -- vazio = vale pra todos
  corpo text not null,             -- markdown com {{campos}}: {{cliente.nome}}, {{proposta.valor}}...
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('modelos_documento', 'admin');

create table propostas (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  numero int not null,
  lead_id uuid references leads(id) on delete set null,
  cliente_id uuid references clientes(id) on delete set null,
  servico_id uuid references servicos(id) on delete set null,
  titulo text not null,
  para_quem text not null,         -- nome que aparece na proposta
  ambientes text[],
  o_que_inclui text,               -- escopo em linguagem do cliente
  o_que_nao_inclui text,
  etapas_texto text,               -- como vai ser (reuniões, 3D, executivo)
  limite_alteracoes int check (limite_alteracoes is null or limite_alteracoes >= 0),
  prazo_dias_uteis int check (prazo_dias_uteis is null or prazo_dias_uteis > 0),
  valor_centavos bigint check (valor_centavos is null or valor_centavos >= 0),
  condicoes_pagamento text,
  validade_ate date,
  status text not null default 'rascunho' check (status in
    ('rascunho', 'enviada', 'aceita', 'recusada', 'expirada', 'substituida')),
  enviada_em timestamptz,
  respondida_em timestamptz,
  link_publico_token text unique,  -- página da proposta pro cliente ver e aceitar
  pdf_url text,
  conteudo_enviado jsonb,          -- cópia congelada no envio
  substitui_id uuid references propostas(id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid,
  unique (org_id, numero)
);
select preparar_tabela('propostas', 'admin');
create index propostas_lead on propostas (lead_id);

create table proposta_itens (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  proposta_id uuid not null references propostas(id) on delete cascade,
  ordem int not null default 0,
  descricao text not null,
  valor_centavos bigint check (valor_centavos is null or valor_centavos >= 0),
  opcional boolean not null default false,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('proposta_itens', 'admin');

create or replace function proposta_numero() returns trigger
language plpgsql as $$
begin
  if new.numero is null then
    perform pg_advisory_xact_lock(hashtext(new.org_id::text || 'proposta'));
    select coalesce(max(numero), 0) + 1 into new.numero from propostas where org_id = new.org_id;
  end if;
  return new;
end; $$;
create trigger propostas_numero before insert on propostas for each row execute function proposta_numero();

-- Proposta enviada → lead vai pra "proposta enviada"; aceita → lead ganho.
create or replace function proposta_mexe_no_lead() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.lead_id is null or (tg_op = 'UPDATE' and new.status = old.status) then return new; end if;
  if new.status = 'enviada' then
    update leads set etapa = 'proposta_enviada', valor_estimado_centavos = coalesce(new.valor_centavos, valor_estimado_centavos)
    where id = new.lead_id and etapa not in ('ganho', 'perdido');
    new.enviada_em := coalesce(new.enviada_em, now());
  elsif new.status in ('aceita', 'recusada') then
    new.respondida_em := coalesce(new.respondida_em, now());
  end if;
  return new;
end; $$;
create trigger propostas_lead before insert or update on propostas for each row execute function proposta_mexe_no_lead();

alter table projetos add constraint projetos_proposta_fk foreign key (proposta_id) references propostas(id) on delete set null;

create table contratos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  cliente_id uuid not null references clientes(id) on delete restrict,
  proposta_id uuid references propostas(id) on delete set null,
  projeto_id uuid references projetos(id) on delete set null,
  modelo_id uuid references modelos_documento(id) on delete set null,
  status text not null default 'rascunho' check (status in
    ('rascunho', 'enviado', 'assinado', 'cancelado')),
  texto_final text,                -- contrato montado (modelo + dados), congelado no envio
  pdf_url text,
  assinatura_provedor text,        -- ex.: autentique (decidir com a Luma)
  assinatura_ref text,
  enviado_em timestamptz,
  assinado_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('contratos', 'admin');
