import Link from "next/link";
import { Cartao, Selo, Titulo, Vazio } from "@/components/ui";
import { mudarTarefa } from "@/lib/acoes";
import { contexto } from "@/lib/contexto";
import { dinheiro, hojeISO, hora } from "@/lib/formato";
import { AREAS_TAREFA, TIPO_REUNIAO, nomeEtapa } from "@/lib/rotulos";

type Dia = {
  reunioes: { id: string; tipo: string; quando: string; onde: string | null; com: string | null; projeto: string | null }[];
  tarefas_hoje: { id: string; titulo: string; prazo: string; prioridade: string; area: string }[];
  leads_novos: number;
  leads_pra_retornar: { id: string; nome: string; etapa: string; proxima_acao: string | null }[];
  leads_parados: { id: string; nome: string; etapa: string; dias: number }[];
  projetos_em_andamento: number;
  financeiro: { receber_hoje_centavos: number; pagar_hoje_centavos: number; atrasados: number } | null;
};

export default async function Hoje() {
  const { sb, org, nome } = await contexto();
  const { data, error } = await sb.rpc("visao_do_dia", { p_org: org, p_dia: hojeISO() });
  if (error) throw new Error(error.message);
  const d = data as Dia;

  return (
    <>
      <Titulo explica="O que pede você hoje. Só isso.">Oi, {nome}</Titulo>
      <div className="grid gap-4 md:grid-cols-2">
        <Cartao titulo="Reuniões de hoje">
          {d.reunioes.length === 0 ? <Vazio>Nenhuma reunião hoje.</Vazio> : (
            <ul className="flex flex-col gap-2 text-sm">
              {d.reunioes.map((r) => (
                <li key={r.id}><b>{hora(r.quando)}</b> · {TIPO_REUNIAO[r.tipo] ?? r.tipo} com {r.com ?? "—"}{r.onde ? ` · ${r.onde}` : ""}</li>
              ))}
            </ul>
          )}
        </Cartao>

        <Cartao titulo="Quem chegou">
          <p className="text-sm">
            {d.leads_novos === 0 ? "Ninguém novo esperando resposta." : `${d.leads_novos} ${d.leads_novos === 1 ? "pessoa esperando" : "pessoas esperando"} sua resposta.`}
          </p>
          {d.leads_pra_retornar.length > 0 && (
            <ul className="mt-3 flex flex-col gap-1 text-sm">
              {d.leads_pra_retornar.map((l) => <li key={l.id}>Retornar {l.nome}{l.proxima_acao ? `: ${l.proxima_acao}` : ""}</li>)}
            </ul>
          )}
          {d.leads_parados.length > 0 && (
            <ul className="mt-3 flex flex-col gap-1 text-sm text-aviso">
              {d.leads_parados.map((l) => <li key={l.id}>{l.nome} está em “{nomeEtapa(l.etapa)}” há {l.dias} dias</li>)}
            </ul>
          )}
          <Link href="/crm" className="mt-3 inline-block text-sm text-marca underline">Abrir quem chegou</Link>
        </Cartao>

        <Cartao titulo="Tarefas pra hoje" className="md:col-span-2">
          {d.tarefas_hoje.length === 0 ? <Vazio>Nada vencendo hoje.</Vazio> : (
            <ul className="flex flex-col divide-y divide-linha">
              {d.tarefas_hoje.map((t) => (
                <li key={t.id} className="flex items-center gap-3 py-2 text-sm">
                  <form action={mudarTarefa}>
                    <input type="hidden" name="id" value={t.id} />
                    <input type="hidden" name="status" value="feita" />
                    <button aria-label="Marcar como feita" className="size-5 rounded-card border border-marca" />
                  </form>
                  <span className="flex-1">{t.titulo}</span>
                  {t.prioridade === "urgente" && <Selo tom="erro">Urgente</Selo>}
                  <Selo>{AREAS_TAREFA[t.area] ?? t.area}</Selo>
                  {t.prazo < hojeISO() && <Selo tom="aviso">Atrasada</Selo>}
                </li>
              ))}
            </ul>
          )}
        </Cartao>

        <Cartao titulo="Projetos">
          <p className="text-sm">{d.projetos_em_andamento} em andamento.</p>
          <Link href="/projetos" className="mt-3 inline-block text-sm text-marca underline">Ver projetos</Link>
        </Cartao>

        {d.financeiro && (
          <Cartao titulo="Dinheiro de hoje">
            <p className="text-sm">A receber: {dinheiro(d.financeiro.receber_hoje_centavos)}</p>
            <p className="text-sm">A pagar: {dinheiro(d.financeiro.pagar_hoje_centavos)}</p>
            {d.financeiro.atrasados > 0 && <p className="mt-2 text-sm text-aviso">{d.financeiro.atrasados} em atraso.</p>}
          </Cartao>
        )}
      </div>
    </>
  );
}
