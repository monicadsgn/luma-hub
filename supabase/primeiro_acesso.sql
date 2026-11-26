-- Hub da Luma: primeiro acesso. Rodar UMA vez, depois de criar o usuário da Luma em
-- Authentication → Users → Add user. Troque só o e-mail da linha marcada.
-- Cria o escritório, liga a Luma como dona, guarda a identidade do guia de 2025
-- e sugere os serviços com os nomes que ela usou (sem prazo, sem preço, sem nº de alterações).
do $$
declare
  v_email text := 'COLOQUE_O_EMAIL_DA_LUMA_AQUI';   -- <<< troque aqui
  v_user uuid;
  v_org uuid;
  v_interiores uuid;
begin
  select id into v_user from auth.users where lower(email) = lower(v_email);
  if v_user is null then raise exception 'Não achei o usuário %. Crie em Authentication → Users primeiro.', v_email; end if;
  if exists (select 1 from organizacoes) then raise exception 'O escritório já foi criado. Não precisa rodar de novo.'; end if;

  insert into organizacoes (nome) values ('Luma Almeida') returning id into v_org;
  insert into membros (org_id, user_id, nome, email, papel) values (v_org, v_user, 'Luma', v_email, 'admin');
  insert into estudio (org_id, nome_publico, cidade, instagram)
    values (v_org, 'Luma Almeida', 'Recife', '@arq.lumaalmeida');
  insert into identidade_marca (org_id, cores, fonte_titulo, fonte_texto)
    values (v_org,
      '[{"nome":"Areia","hex":"#c0a793"},{"nome":"Caramelo","hex":"#a86539"},{"nome":"Preto","hex":"#181515"},{"nome":"Branco","hex":"#fffaf5"}]',
      'Playfair Display', 'Montserrat');

  insert into servicos (org_id, nome, ordem, aparece_no_site) values
    (v_org, 'Projeto de interiores', 1, true),
    (v_org, 'Projeto arquitetônico para aprovação', 2, true),
    (v_org, 'Área de piscina e área gourmet', 3, true),
    (v_org, 'Iluminação', 4, false),
    (v_org, 'Vistoria na entrega do imóvel', 5, true),
    (v_org, 'Assinatura de projeto', 6, false);
  select id into v_interiores from servicos where org_id = v_org and nome = 'Projeto de interiores';
  insert into servico_etapas (org_id, servico_id, ordem, nome, tem_reuniao, reuniao_tipo) values
    (v_org, v_interiores, 1, 'Conversa inicial e medição', true, 'briefing'),
    (v_org, v_interiores, 2, 'Conferir medidas', false, null),
    (v_org, v_interiores, 3, 'Apresentação do 3D', true, 'apresentacao_3d'),
    (v_org, v_interiores, 4, 'Ajustes do 3D', true, 'ajuste'),
    (v_org, v_interiores, 5, 'Projeto executivo', false, null),
    (v_org, v_interiores, 6, 'Entrega do executivo', true, 'entrega');

  raise notice 'Pronto. Escritório criado para %.', v_email;
end $$;
