-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0005 · financeiro
--
-- Simples de propósito: o que entra, o que sai, o que está pra vencer.
--   • lancamentos → cada entrada ou saída (parcela de projeto, RRT, software...)
--   • contas_fixas → o que se repete todo mês; o sistema gera o lançamento do mês
-- Só a Luma (admin) lê e escreve.
-- ════════════════════════════════════════════════════════════════════════════

create table categorias_financeiras (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  nome text not null,
  tipo text not null check (tipo in ('entrada', 'saida')),
  ativa boolean not null default true,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid,
  unique (org_id, tipo, nome)
);
select preparar_tabela('categorias_financeiras', 'admin');

create table contas_fixas (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  nome text not null,
  categoria_id uuid references categorias_financeiras(id) on delete set null,
  valor_centavos bigint check (valor_centavos is null or valor_centavos >= 0),
  dia_vencimento int check (dia_vencimento is null or dia_vencimento between 1 and 31),
  ativa boolean not null default true,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('contas_fixas', 'admin');

create table lancamentos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  tipo text not null check (tipo in ('entrada', 'saida')),
  descricao text not null,
  categoria_id uuid references categorias_financeiras(id) on delete set null,
  valor_centavos bigint not null check (valor_centavos >= 0),
  vencimento date not null,
  pago_em date,
  status text not null default 'previsto' check (status in ('previsto', 'pago', 'cancelado')),
  forma text check (forma is null or forma in ('pix', 'transferencia', 'cartao', 'boleto', 'dinheiro', 'outra')),
  parcela int check (parcela is null or parcela > 0),
  parcelas int check (parcelas is null or parcelas > 0),
  cliente_id uuid references clientes(id) on delete set null,
  projeto_id uuid references projetos(id) on delete set null,
  proposta_id uuid references propostas(id) on delete set null,
  conta_fixa_id uuid references contas_fixas(id) on delete set null,
  comprovante_url text,
  observacoes text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('lancamentos', 'admin');
create index lancamentos_org_venc on lancamentos (org_id, vencimento);
create unique index lancamentos_fixa_mes on lancamentos (conta_fixa_id, date_trunc('month', vencimento::timestamp))
  where conta_fixa_id is not null;

create or replace function lancamento_pago() returns trigger
language plpgsql as $$
begin
  if new.status = 'pago' and new.pago_em is null then new.pago_em := current_date; end if;
  if new.status <> 'pago' then new.pago_em := null; end if;
  return new;
end; $$;
create trigger lancamentos_pago before insert or update on lancamentos for each row execute function lancamento_pago();

-- Gera os lançamentos das contas fixas de um mês (pode rodar mais de uma vez: não duplica).
create or replace function gerar_contas_do_mes(p_org uuid, p_mes date) returns int
language plpgsql security invoker set search_path = public as $$
declare c contas_fixas; v_n int := 0; v_venc date; v_ult int;
begin
  if not eh_admin(p_org) then raise exception 'Sem acesso.'; end if;
  for c in select * from contas_fixas where org_id = p_org and ativa and valor_centavos is not null loop
    v_ult := extract(day from (date_trunc('month', p_mes) + interval '1 month - 1 day'));
    v_venc := date_trunc('month', p_mes)::date + (least(coalesce(c.dia_vencimento, 1), v_ult) - 1);
    insert into lancamentos (org_id, tipo, descricao, categoria_id, valor_centavos, vencimento, conta_fixa_id)
    values (p_org, 'saida', c.nome, c.categoria_id, c.valor_centavos, v_venc, c.id)
    on conflict do nothing;
    if found then v_n := v_n + 1; end if;
  end loop;
  return v_n;
end; $$;

-- Resumo do mês: entrou, saiu, falta receber, falta pagar, atrasados.
create or replace function resumo_financeiro(p_org uuid, p_mes date) returns jsonb
language sql stable security invoker set search_path = public as $$
  with m as (select * from lancamentos where org_id = p_org and status <> 'cancelado'
             and date_trunc('month', vencimento) = date_trunc('month', p_mes))
  select jsonb_build_object(
    'entrou_centavos', coalesce(sum(valor_centavos) filter (where tipo = 'entrada' and status = 'pago'), 0),
    'saiu_centavos', coalesce(sum(valor_centavos) filter (where tipo = 'saida' and status = 'pago'), 0),
    'falta_receber_centavos', coalesce(sum(valor_centavos) filter (where tipo = 'entrada' and status = 'previsto'), 0),
    'falta_pagar_centavos', coalesce(sum(valor_centavos) filter (where tipo = 'saida' and status = 'previsto'), 0),
    'atrasados', (select count(*) from lancamentos a where a.org_id = p_org and a.status = 'previsto' and a.vencimento < current_date)
  ) from m where eh_admin(p_org);
$$;
