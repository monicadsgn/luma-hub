// Entrada pública do pré-briefing (todo botão do site leva até ele).
// Sem login: quem protege é o segredo (PRE_BRIEFING_SEGREDO; no banco só o hash), o limite por hora por
// visitante (hash do IP, nunca o IP), a armadilha pra robô e a validação de lib/preBriefing.ts.
import "server-only";
import { createHash } from "node:crypto";
import { LIMITE_ENVIOS_POR_HORA, LIMITE_PASSOS_POR_HORA, TAMANHO_MAXIMO, lerPedido } from "@/lib/preBriefing";
import { bancoDoServidor } from "@/lib/supabase/servidor";

const responder = (corpo: Record<string, unknown>, status = 200) =>
  Response.json(corpo, { status, headers: { "Cache-Control": "no-store" } });

const FORA_DO_AR = "O formulário está fora do ar agora. Chame no WhatsApp.";

function erroDoBanco(msg: string) {
  if (/Muitas tentativas/.test(msg)) return responder({ erro: msg }, 429);
  if (/não configurado/.test(msg)) return responder({ erro: FORA_DO_AR }, 503);
  if (/^(Informe|Pedido inválido)/.test(msg)) return responder({ erro: msg }, 400);
  return responder({ erro: "Não deu pra enviar agora. Tente de novo." }, 500);
}

export async function POST(req: Request) {
  const segredo = process.env.PRE_BRIEFING_SEGREDO;
  const sb = bancoDoServidor();
  if (!segredo || !sb) return responder({ erro: FORA_DO_AR }, 503);

  const bruto = await req.text().catch(() => "");
  if (bruto.length > TAMANHO_MAXIMO) return responder({ erro: "Pedido grande demais." }, 413);

  let pedido;
  try {
    pedido = lerPedido(JSON.parse(bruto));
  } catch (e) {
    return responder({ erro: e instanceof Error && !(e instanceof SyntaxError) ? e.message : "Pedido inválido." }, 400);
  }
  if (pedido.acao === "enviar" && pedido.robo) return responder({ ok: true });

  const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "sem-ip";
  const chave = createHash("sha256").update(`${segredo}:${ip}`).digest("hex");
  const tipo = pedido.acao;
  const lim = await sb.rpc("pre_briefing_limite_checar", {
    p_segredo: segredo, p_chave: chave, p_tipo: tipo,
    p_max: tipo === "passo" ? LIMITE_PASSOS_POR_HORA : LIMITE_ENVIOS_POR_HORA,
  });
  if (lim.error) return erroDoBanco(lim.error.message);

  if (pedido.acao === "passo") {
    const { error } = await sb.rpc("pre_briefing_passo", {
      p_segredo: segredo, p_sessao: pedido.sessao, p_passo: pedido.passo,
      p_botao: pedido.botao ?? null, p_campanha: pedido.campanha ?? null,
    });
    return error ? erroDoBanco(error.message) : responder({ ok: true });
  }

  const { error } = await sb.rpc("pre_briefing_enviar", { p_segredo: segredo, p_dados: pedido.dados });
  return error ? erroDoBanco(error.message) : responder({ ok: true });
}
