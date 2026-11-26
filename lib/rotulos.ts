export const ETAPAS_LEAD = [
  { id: "novo", nome: "Chegou", explica: "Mandou o pré-briefing ou entrou em contato. Ainda sem resposta sua." },
  { id: "em_conversa", nome: "Em conversa", explica: "Você já respondeu e estão conversando." },
  { id: "reuniao_marcada", nome: "Reunião marcada", explica: "Primeira conversa ou medição agendada." },
  { id: "proposta_enviada", nome: "Proposta enviada", explica: "Esperando a resposta da proposta." },
  { id: "ganho", nome: "Fechou", explica: "Virou cliente." },
  { id: "perdido", nome: "Não fechou", explica: "Desistiu ou sumiu. Guarde o motivo." },
] as const;
export type EtapaLead = (typeof ETAPAS_LEAD)[number]["id"];
export const nomeEtapa = (id: string) => ETAPAS_LEAD.find((e) => e.id === id)?.nome ?? id;

export const ORIGENS = [
  { id: "site", nome: "Site" },
  { id: "instagram", nome: "Instagram" },
  { id: "loja", nome: "Loja" },
  { id: "indicacao", nome: "Indicação" },
  { id: "whatsapp", nome: "WhatsApp" },
  { id: "outro", nome: "Outro" },
] as const;
export const nomeOrigem = (id: string) => ORIGENS.find((o) => o.id === id)?.nome ?? id;

export const STATUS_PROJETO: Record<string, string> = {
  aguardando_inicio: "Vai começar",
  em_andamento: "Em andamento",
  aguardando_cliente: "Esperando o cliente",
  pausado: "Pausado",
  entregue: "Entregue",
  cancelado: "Cancelado",
};

export const TIPO_REUNIAO: Record<string, string> = {
  briefing: "Conversa inicial",
  medicao: "Medição",
  apresentacao_3d: "Apresentação do 3D",
  ajuste: "Ajuste",
  entrega: "Entrega",
  vistoria: "Vistoria",
  primeira_conversa: "Primeira conversa",
  outra: "Reunião",
};

export const AREAS_TAREFA: Record<string, string> = {
  projeto: "Projeto",
  comercial: "Comercial",
  financeiro: "Financeiro",
  conteudo: "Conteúdo",
  pessoal: "Pessoal",
  outra: "Outra",
};
