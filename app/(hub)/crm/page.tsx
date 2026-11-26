import { Botao, Campo, Cartao, Escolha, Selo, Titulo, Vazio } from "@/components/ui";
import { anotarConversa, moverLead, novoLead } from "@/lib/acoes";
import { contexto } from "@/lib/contexto";
import { data, hojeISO } from "@/lib/formato";
import { ETAPAS_LEAD, ORIGENS, nomeOrigem } from "@/lib/rotulos";

type Lead = {
  id: string; nome: string; telefone: string | null; origem: string; etapa: string; servico_texto: string | null;
  ambientes: string[] | null; mensagem: string | null; botao_origem: string | null; proximo_contato: string | null;
  proxima_acao: string | null; entrou_na_etapa_em: string; criado_em: string;
};
type Funil = { abriram_pre_briefing: number; nao_terminaram: number; leads_novos: number; ganhos: number; onde_pararam: Record<string, number> };

const ABERTAS = ETAPAS_LEAD.filter((e) => e.id !== "ganho" && e.id !== "perdido");

export default async function Crm() {
  const { sb, org } = await contexto();
  const hoje = hojeISO();
  const inicioMes = hoje.slice(0, 8) + "01";
  const [{ data: leads, error }, { data: funil }] = await Promise.all([
    sb.from("leads").select("*").order("criado_em", { ascending: false }).limit(300),
    sb.rpc("funil", { p_org: org, p_de: inicioMes, p_ate: hoje }),
  ]);
  if (error) throw new Error(error.message);
  const f = funil as Funil | null;
  const lista = (leads ?? []) as Lead[];
  const whats = (t: string | null) => (t ? `https://wa.me/55${t.replace(/\D/g, "").replace(/^55/, "")}` : null);

  return (
    <>
      <Titulo explica="Todo mundo que chegou pelo site, Instagram, loja ou indicação, e em que pé está.">Quem chegou</Titulo>

      {f && (
        <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-4">
          {[
            ["Abriram o pré-briefing", f.abriram_pre_briefing, "neste mês"],
            ["Pararam no meio", f.nao_terminaram, "abriram e não mandaram"],
            ["Chegaram", f.leads_novos, "neste mês, de todas as origens"],
            ["Fecharam", f.ganhos, "neste mês"],
          ].map(([t, n, e]) => (
            <Cartao key={String(t)}><p className="text-2xl font-titulo">{n}</p><p className="text-sm">{t}</p><p className="text-xs text-suave">{e}</p></Cartao>
          ))}
        </div>
      )}

      <div className="grid gap-4 lg:grid-cols-4">
        {ABERTAS.map((etapa) => {
          const daqui = lista.filter((l) => l.etapa === etapa.id);
          return (
            <section key={etapa.id} className="flex flex-col gap-3">
              <header><h2 className="text-lg">{etapa.nome} <span className="text-suave">({daqui.length})</span></h2><p className="text-xs text-suave">{etapa.explica}</p></header>
              {daqui.length === 0 && <Vazio>Ninguém aqui.</Vazio>}
              {daqui.map((l) => (
                <Cartao key={l.id} className="text-sm">
                  <p className="font-medium">{l.nome}</p>
                  <div className="mt-1 flex flex-wrap gap-1"><Selo>{nomeOrigem(l.origem)}</Selo>{l.servico_texto && <Selo tom="marca">{l.servico_texto}</Selo>}</div>
                  {l.ambientes?.length ? <p className="mt-2 text-suave">{l.ambientes.join(", ")}</p> : null}
                  {l.mensagem && <p className="mt-2 line-clamp-3 text-suave">{l.mensagem}</p>}
                  <p className="mt-2 text-xs text-suave">Chegou em {data(l.criado_em)}</p>
                  {l.proximo_contato && <p className={`text-xs ${l.proximo_contato <= hoje ? "text-aviso" : "text-suave"}`}>Retornar em {data(l.proximo_contato)}{l.proxima_acao ? `: ${l.proxima_acao}` : ""}</p>}
                  {whats(l.telefone) && <a className="mt-2 inline-block text-marca underline" href={whats(l.telefone)!} target="_blank" rel="noreferrer">Abrir WhatsApp</a>}
                  <form action={moverLead} className="mt-3 flex gap-2">
                    <input type="hidden" name="id" value={l.id} />
                    <select name="etapa" defaultValue={l.etapa} className="flex-1 rounded-card border border-linha bg-fundo px-2 py-1">
                      {ETAPAS_LEAD.map((e) => <option key={e.id} value={e.id}>{e.nome}</option>)}
                    </select>
                    <Botao variante="leve" className="px-3 py-1">Mover</Botao>
                  </form>
                  <details className="mt-2">
                    <summary className="cursor-pointer text-suave">Anotar conversa</summary>
                    <form action={anotarConversa} className="mt-2 flex flex-col gap-2">
                      <input type="hidden" name="lead_id" value={l.id} />
                      <textarea name="texto" required className="rounded-card border border-linha bg-fundo p-2" rows={2} />
                      <Campo rotulo="Retornar em" name="proximo_contato" type="date" />
                      <Campo rotulo="Pra quê" name="proxima_acao" />
                      <Botao variante="leve">Salvar</Botao>
                    </form>
                  </details>
                </Cartao>
              ))}
            </section>
          );
        })}
      </div>

      <Cartao titulo="Alguém chegou por fora do site?" className="mt-8">
        <form action={novoLead} className="grid gap-3 md:grid-cols-3">
          <Campo rotulo="Nome" name="nome" required />
          <Campo rotulo="WhatsApp" name="telefone" />
          <Escolha rotulo="De onde veio" name="origem" opcoes={ORIGENS.map((o) => ({ ...o }))} defaultValue="instagram" />
          <Campo rotulo="O que quer" name="servico" />
          <Campo rotulo="Recado" name="mensagem" className="md:col-span-2" />
          <Botao className="md:col-start-3">Guardar</Botao>
        </form>
      </Cartao>
    </>
  );
}
