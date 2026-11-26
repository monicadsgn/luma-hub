// Valida o que chega do formulário público antes de ir pro banco.
// O banco valida de novo (pre_briefing_enviar). Nenhuma regra de qualificação aqui.
import { z } from "zod";

export const TAMANHO_MAXIMO = 20_000;
export const LIMITE_ENVIOS_POR_HORA = 5;
export const LIMITE_PASSOS_POR_HORA = 120;

const texto = (max: number) => z.string().trim().max(max).optional();

const dados = z.object({
  sessao: z.uuid().optional(),
  nome: z.string().trim().min(1, "Informe seu nome.").max(120),
  telefone: z.string().trim().refine((t) => t.replace(/\D/g, "").length >= 10, "Informe um WhatsApp com DDD."),
  email: texto(160),
  instagram: texto(60),
  cidade: texto(80),
  servico: texto(120),
  tipo_imovel: texto(40),
  ambientes: z.array(z.string().trim().max(60)).max(20).optional(),
  metragem_m2: z.union([z.number().positive().max(100000), z.string().regex(/^\d+([.,]\d+)?$/)]).optional(),
  tem_planta: z.boolean().optional(),
  quando_comecar: texto(80),
  faixa_investimento: texto(80),
  como_conheceu: texto(200),
  mensagem: texto(2000),
  botao: texto(60),
  campanha: z.record(z.string().max(40), z.string().max(120)).optional(),
  site: z.string().optional(), // armadilha pra robô: gente de verdade deixa vazio
});

const passo = z.object({
  acao: z.literal("passo"),
  sessao: z.uuid(),
  passo: z.string().trim().min(1).max(40),
  botao: texto(60),
  campanha: z.record(z.string().max(40), z.string().max(120)).optional(),
});

const enviar = z.object({ acao: z.literal("enviar"), dados });

export type PedidoPreBriefing =
  | z.infer<typeof passo>
  | { acao: "enviar"; dados: Omit<z.infer<typeof dados>, "site">; robo: boolean };

export function lerPedido(bruto: unknown): PedidoPreBriefing {
  const r = z.discriminatedUnion("acao", [passo, enviar]).safeParse(bruto);
  if (!r.success) throw new Error(r.error.issues[0]?.message ?? "Pedido inválido.");
  if (r.data.acao === "passo") return r.data;
  const { site, ...resto } = r.data.dados;
  if (typeof resto.metragem_m2 === "string") resto.metragem_m2 = Number(resto.metragem_m2.replace(",", "."));
  return { acao: "enviar", dados: resto, robo: Boolean(site) };
}
