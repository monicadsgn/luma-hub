-- Sugestão de serviços e etapas, com os NOMES que a Luma usou na reunião de 23/11/2026.
-- Nenhum número (prazo, nº de alterações, preço): ela preenche no hub.
-- Rodar só depois de criar a organização. Troque <ORG> pelo id dela.
insert into servicos (org_id, nome, ordem, aparece_no_site) values
  ('<ORG>', 'Projeto de interiores', 1, true),
  ('<ORG>', 'Projeto arquitetônico para aprovação', 2, true),
  ('<ORG>', 'Área de piscina e área gourmet', 3, true),
  ('<ORG>', 'Iluminação', 4, false),           -- ela prefere vender dentro de interiores
  ('<ORG>', 'Vistoria na entrega do imóvel', 5, true),
  ('<ORG>', 'Assinatura de projeto', 6, false);

-- O passo a passo que ela descreveu, pro serviço de interiores.
insert into servico_etapas (org_id, servico_id, ordem, nome, tem_reuniao, reuniao_tipo)
select '<ORG>', s.id, e.ordem, e.nome, e.reuniao is not null, e.reuniao
from servicos s, (values
  (1, 'Briefing e medição', 'briefing'),
  (2, 'Conferir medidas', null),
  (3, 'Modelagem e apresentação do 3D', 'apresentacao_3d'),
  (4, 'Ajustes do 3D', 'ajuste'),
  (5, 'Projeto executivo', null),
  (6, 'Entrega do executivo', 'entrega')
) as e(ordem, nome, reuniao)
where s.org_id = '<ORG>' and s.nome = 'Projeto de interiores';
