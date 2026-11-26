-- ════════════════════════════════════════════════════════════════════════════
-- Hub da Luma · 0006 · portfólio (o que o site mostra)
--
-- A Luma decide no hub o que aparece no site. Trava importante (pendência do
-- briefing: "quais projetos pode mostrar, foto real ou render, quem autoriza"):
-- um projeto só aparece no site se estiver PUBLICADO **e** AUTORIZADO.
-- O site (sem login) lê só pela função portfolio_publico, nunca as tabelas.
-- ════════════════════════════════════════════════════════════════════════════

create table portfolio_projetos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  projeto_id uuid references projetos(id) on delete set null,  -- liga ao projeto real, se houver
  slug text not null,
  titulo text not null,
  resumo text,                     -- 1 ou 2 frases, linguagem dela
  ambientes text[],
  cidade text,
  tipo_imagem text check (tipo_imagem is null or tipo_imagem in ('foto_real', 'render', 'misto')),
  autorizado boolean not null default false,        -- cliente/dono autorizou mostrar
  autorizado_por text,
  publicado boolean not null default false,
  destaque boolean not null default false,
  capa_url text,
  ordem int not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid,
  unique (org_id, slug)
);
select preparar_tabela('portfolio_projetos', 'membro');

create table portfolio_fotos (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references organizacoes(id) on delete cascade,
  portfolio_id uuid not null references portfolio_projetos(id) on delete cascade,
  url text not null,
  legenda text,
  ambiente text,
  ordem int not null default 0,
  atualizado_em timestamptz not null default now(),
  atualizado_por uuid
);
select preparar_tabela('portfolio_fotos', 'membro');

-- O que o site pode ler (sem login). Nada interno sai daqui.
create or replace function portfolio_publico() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
      'slug', p.slug, 'titulo', p.titulo, 'resumo', p.resumo, 'ambientes', p.ambientes,
      'cidade', p.cidade, 'tipo_imagem', p.tipo_imagem, 'destaque', p.destaque, 'capa_url', p.capa_url,
      'fotos', (select coalesce(jsonb_agg(jsonb_build_object('url', f.url, 'legenda', f.legenda, 'ambiente', f.ambiente)
                 order by f.ordem), '[]') from portfolio_fotos f where f.portfolio_id = p.id)
    ) order by p.destaque desc, p.ordem), '[]')
  from portfolio_projetos p
  where p.publicado and p.autorizado and p.org_id = (select org_id from pre_briefing_config limit 1);
$$;

create or replace function site_publico() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'nome', e.nome_publico, 'cidade', e.cidade, 'instagram', e.instagram, 'whatsapp', e.whatsapp,
    'registro_cau', e.registro_cau,
    'marca', (select jsonb_build_object('cores', m.cores, 'fonte_titulo', m.fonte_titulo,
              'fonte_texto', m.fonte_texto, 'logo_url', m.logo_url, 'logo_claro_url', m.logo_claro_url)
              from identidade_marca m where m.org_id = e.org_id),
    'servicos', (select coalesce(jsonb_agg(jsonb_build_object('nome', s.nome, 'descricao', s.descricao_cliente)
              order by s.ordem), '[]') from servicos s where s.org_id = e.org_id and s.ativo and s.aparece_no_site)
  ) from estudio e where e.org_id = (select org_id from pre_briefing_config limit 1);
$$;

grant execute on function portfolio_publico() to anon, authenticated;
grant execute on function site_publico() to anon, authenticated;
