import { Botao, Campo, Cartao, Escolha, Selo, Titulo, Vazio } from "@/components/ui";
import { mudarTarefa, novaTarefa } from "@/lib/acoes";
import { contexto } from "@/lib/contexto";
import { data, hojeISO } from "@/lib/formato";
import { AREAS_TAREFA } from "@/lib/rotulos";

type Tarefa = { id: string; titulo: string; status: string; prioridade: string; prazo: string | null; area: string; bloqueada_por: string | null; projetos: { nome: string } | null };

export default async function Tarefas() {
  const { sb } = await contexto();
  const { data: linhas, error } = await sb.from("tarefas").select("id, titulo, status, prioridade, prazo, area, bloqueada_por, projetos(nome)")
    .in("status", ["a_fazer", "fazendo"]).order("prazo", { ascending: true, nullsFirst: false }).limit(300);
  if (error) throw new Error(error.message);
  const todas = (linhas ?? []) as unknown as Tarefa[];
  const abertas = new Set(todas.map((t) => t.id));
  const liberadas = todas.filter((t) => !t.bloqueada_por || !abertas.has(t.bloqueada_por));
  const esperando = todas.length - liberadas.length;
  const hoje = hojeISO();

  return (
    <>
      <Titulo explica="Só aparece o que já dá pra fazer. Etapa de projeto aparece quando a anterior fecha.">Tarefas</Titulo>
      <Cartao titulo="Nova tarefa" className="mb-6">
        <form action={novaTarefa} className="grid gap-3 md:grid-cols-4">
          <Campo rotulo="O que fazer" name="titulo" required className="md:col-span-2" />
          <Campo rotulo="Até quando" name="prazo" type="date" />
          <Escolha rotulo="Área" name="area" defaultValue="outra" opcoes={Object.entries(AREAS_TAREFA).map(([id, nome]) => ({ id, nome }))} />
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="urgente" /> Urgente</label>
          <Botao className="md:col-start-4">Adicionar</Botao>
        </form>
      </Cartao>
      <Cartao>
        {liberadas.length === 0 ? <Vazio>Nenhuma tarefa aberta.</Vazio> : (
          <ul className="flex flex-col divide-y divide-linha">
            {liberadas.map((t) => (
              <li key={t.id} className="flex flex-wrap items-center gap-3 py-2 text-sm">
                <form action={mudarTarefa}><input type="hidden" name="id" value={t.id} /><input type="hidden" name="status" value="feita" />
                  <button aria-label="Marcar como feita" className="size-5 rounded-card border border-marca" /></form>
                <span className="flex-1">{t.titulo}</span>
                {t.prioridade === "urgente" && <Selo tom="erro">Urgente</Selo>}
                <Selo>{AREAS_TAREFA[t.area] ?? t.area}</Selo>
                <span className={t.prazo && t.prazo < hoje ? "text-aviso" : "text-suave"}>{data(t.prazo)}</span>
              </li>
            ))}
          </ul>
        )}
        {esperando > 0 && <p className="mt-3 text-xs text-suave">{esperando} {esperando === 1 ? "tarefa espera" : "tarefas esperam"} a etapa anterior do projeto.</p>}
      </Cartao>
    </>
  );
}
