"use server";
// Tudo que a tela grava passa por aqui. O banco confere a permissão (RLS) e guarda o histórico.
import { revalidatePath } from "next/cache";
import { contexto } from "./contexto";
import { paraCentavos } from "./formato";

const txt = (f: FormData, k: string) => {
  const v = f.get(k);
  return typeof v === "string" && v.trim() ? v.trim() : null;
};
function ok(e: { message: string } | null) {
  if (e) throw new Error(e.message);
}

// ─── CRM ────────────────────────────────────────────────────────────────────
export async function novoLead(f: FormData) {
  const { sb, org } = await contexto();
  const nome = txt(f, "nome");
  if (!nome) throw new Error("Informe o nome.");
  const { error } = await sb.from("leads").insert({
    org_id: org, nome, telefone: txt(f, "telefone"), instagram: txt(f, "instagram"),
    origem: txt(f, "origem") ?? "outro", servico_texto: txt(f, "servico"), mensagem: txt(f, "mensagem"),
  });
  ok(error);
  revalidatePath("/crm");
}

export async function moverLead(f: FormData) {
  const { sb } = await contexto();
  const id = txt(f, "id")!;
  const etapa = txt(f, "etapa")!;
  if (etapa === "ganho") {
    ok((await sb.rpc("ganhar_lead", { p_lead: id })).error);
  } else {
    ok((await sb.from("leads").update({ etapa, motivo_perda: etapa === "perdido" ? txt(f, "motivo") : null }).eq("id", id)).error);
  }
  revalidatePath("/crm");
  revalidatePath("/hoje");
}

export async function anotarConversa(f: FormData) {
  const { sb, org, nome } = await contexto();
  const texto = txt(f, "texto");
  if (!texto) return;
  ok((await sb.from("lead_interacoes").insert({
    org_id: org, lead_id: txt(f, "lead_id"), tipo: txt(f, "tipo") ?? "nota", texto, autor_nome: nome,
  })).error);
  const proximo = txt(f, "proximo_contato");
  if (proximo) ok((await sb.from("leads").update({ proximo_contato: proximo, proxima_acao: txt(f, "proxima_acao") }).eq("id", txt(f, "lead_id")!)).error);
  revalidatePath("/crm");
}

// ─── Tarefas ────────────────────────────────────────────────────────────────
export async function novaTarefa(f: FormData) {
  const { sb, org } = await contexto();
  const titulo = txt(f, "titulo");
  if (!titulo) throw new Error("Escreva a tarefa.");
  ok((await sb.from("tarefas").insert({
    org_id: org, titulo, prazo: txt(f, "prazo"), area: txt(f, "area") ?? "outra",
    prioridade: f.get("urgente") ? "urgente" : "normal",
  })).error);
  revalidatePath("/tarefas");
  revalidatePath("/hoje");
}

export async function mudarTarefa(f: FormData) {
  const { sb } = await contexto();
  ok((await sb.from("tarefas").update({ status: txt(f, "status") }).eq("id", txt(f, "id")!)).error);
  revalidatePath("/tarefas");
  revalidatePath("/hoje");
  revalidatePath("/projetos");
}

// ─── Clientes e projetos ────────────────────────────────────────────────────
export async function novoCliente(f: FormData) {
  const { sb, org } = await contexto();
  const nome = txt(f, "nome");
  if (!nome) throw new Error("Informe o nome.");
  ok((await sb.from("clientes").insert({
    org_id: org, nome, telefone: txt(f, "telefone"), email: txt(f, "email"), cidade: txt(f, "cidade"),
  })).error);
  revalidatePath("/clientes");
}

export async function novoProjeto(f: FormData) {
  const { sb, org } = await contexto();
  const nome = txt(f, "nome");
  if (!nome) throw new Error("Dê um nome ao projeto.");
  const ambientes = (txt(f, "ambientes") ?? "").split(",").map((a) => a.trim()).filter(Boolean);
  ok((await sb.rpc("criar_projeto", {
    p_org: org, p_cliente: txt(f, "cliente_id"), p_servico: txt(f, "servico_id"), p_nome: nome,
    p_inicio: txt(f, "inicio"), p_ambientes: ambientes.length ? ambientes : null,
  })).error);
  revalidatePath("/projetos");
  revalidatePath("/tarefas");
}

export async function registrarAlteracao(f: FormData) {
  const { sb, org } = await contexto();
  const pedido = txt(f, "pedido");
  if (!pedido) return;
  ok((await sb.from("alteracoes").insert({ org_id: org, projeto_id: txt(f, "projeto_id"), pedido, fase: txt(f, "fase") ?? "3d" })).error);
  revalidatePath("/projetos");
}

// ─── Financeiro ─────────────────────────────────────────────────────────────
export async function novoLancamento(f: FormData) {
  const { sb, org } = await contexto();
  const descricao = txt(f, "descricao");
  const valor = paraCentavos(txt(f, "valor"));
  if (!descricao || valor == null) throw new Error("Preencha descrição e valor.");
  ok((await sb.from("lancamentos").insert({
    org_id: org, tipo: txt(f, "tipo"), descricao, valor_centavos: valor, vencimento: txt(f, "vencimento"),
    status: f.get("pago") ? "pago" : "previsto", cliente_id: txt(f, "cliente_id"),
  })).error);
  revalidatePath("/financeiro");
}

export async function marcarPago(f: FormData) {
  const { sb } = await contexto();
  ok((await sb.from("lancamentos").update({ status: "pago" }).eq("id", txt(f, "id")!)).error);
  revalidatePath("/financeiro");
}

// ─── Ajustes ────────────────────────────────────────────────────────────────
const CAMPOS_ESTUDIO = ["nome_publico", "nome_contrato", "documento", "registro_cau", "endereco", "cidade", "whatsapp", "email", "instagram", "pix"] as const;

export async function salvarEstudio(f: FormData) {
  const { sb, org } = await contexto();
  const linha: Record<string, unknown> = { org_id: org };
  for (const c of CAMPOS_ESTUDIO) linha[c] = txt(f, c);
  for (const c of ["validade_proposta_dias", "dias_lead_parado"]) {
    const v = txt(f, c);
    linha[c] = v ? Number(v) : null;
  }
  ok((await sb.from("estudio").upsert(linha)).error);
  revalidatePath("/ajustes");
}

export async function salvarServico(f: FormData) {
  const { sb, org } = await contexto();
  const nome = txt(f, "nome");
  if (!nome) throw new Error("Informe o nome do serviço.");
  const n = (k: string) => (txt(f, k) ? Number(txt(f, k)) : null);
  const linha = {
    org_id: org, nome, descricao_cliente: txt(f, "descricao_cliente"),
    prazo_dias_uteis: n("prazo_dias_uteis"), limite_alteracoes: n("limite_alteracoes"),
    aparece_no_site: Boolean(f.get("aparece_no_site")),
  };
  const id = txt(f, "id");
  ok((id ? await sb.from("servicos").update(linha).eq("id", id) : await sb.from("servicos").insert(linha)).error);
  revalidatePath("/ajustes");
}
