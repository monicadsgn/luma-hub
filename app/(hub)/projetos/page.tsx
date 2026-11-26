import { Botao, Campo, Cartao, Escolha, Selo, Titulo, Vazio } from "@/components/ui";
import { novoProjeto, registrarAlteracao } from "@/lib/acoes";
import { contexto } from "@/lib/contexto";
import { data } from "@/lib/formato";
import { STATUS_PROJETO } from "@/lib/rotulos";

type Projeto = {
  id: string; nome: string; status: string; data_entrega_prevista: string | null; limite_alteracoes: number | null; medicao_conferida: boolean;
  clientes: { nome: string } | null;
  projeto_etapas: { id: string; ordem: number; nome: string; status: string; previsto_para: string | null }[];
  alteracoes: { id: string; fora_do_limite: boolean }[];
};

export default async function Projetos() {
  const { sb } = await contexto();
  const [{ data: proj, error }, { data: clientes }, { data: servicos }, { data: tarefas }] = await Promise.all([
    sb.from("projetos").select("id, nome, status, data_entrega_prevista, limite_alteracoes, medicao_conferida, clientes(nome), projeto_etapas(id, ordem, nome, status, previsto_para), alteracoes(id, fora_do_limite)")
      .not("status", "in", "(entregue,cancelado)").order("criado_em", { ascending: false }),
    sb.from("clientes").select("id, nome").eq("ativo", true).order("nome"),
    sb.from("servicos").select("id, nome").eq("ativo", true).order("ordem"),
    sb.from("tarefas").select("etapa_id, status").not("etapa_id", "is", null),
  ]);
  if (error) throw new Error(error.message);
  const feitas = new Set((tarefas ?? []).filter((t) => t.status === "feita").map((t) => t.etapa_id));
  const lista = (proj ?? []) as unknown as Projeto[];

  return (
    <>
      <Titulo explica="Cada projeto com as etapas da Luma: conversa inicial e medição, 3D, ajustes, executivo e entrega.">Projetos</Titulo>
      <div className="mb-6 flex flex-col gap-4">
        {lista.length === 0 && <Cartao><Vazio>Nenhum projeto em andamento.</Vazio></Cartao>}
        {lista.map((p) => {
          const etapas = [...p.projeto_etapas].sort((a, b) => a.ordem - b.ordem);
          const usadas = p.alteracoes.length;
          return (
            <Cartao key={p.id}>
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-lg">{p.nome}</h2>
                <Selo tom="marca">{STATUS_PROJETO[p.status] ?? p.status}</Selo>
                {!p.medicao_conferida && <Selo tom="aviso">Medição não conferida</Selo>}
              </div>
              <p className="text-sm text-suave">{p.clientes?.nome} · entrega prevista {data(p.data_entrega_prevista)}</p>
              <ol className="mt-3 flex flex-wrap gap-2 text-xs">
                {etapas.map((e) => <li key={e.id}><Selo tom={feitas.has(e.id) ? "ok" : "neutro"}>{e.ordem}. {e.nome}</Selo></li>)}
              </ol>
              <p className="mt-3 text-sm">
                Alterações: {usadas}{p.limite_alteracoes != null ? ` de ${p.limite_alteracoes}` : " (sem limite cadastrado)"}
                {p.alteracoes.some((a) => a.fora_do_limite) && <span className="text-aviso"> · passou do limite</span>}
              </p>
              <form action={registrarAlteracao} className="mt-2 flex gap-2">
                <input type="hidden" name="projeto_id" value={p.id} />
                <input name="pedido" placeholder="O que o cliente pediu pra mudar" className="flex-1 rounded-card border border-linha bg-fundo px-3 py-1 text-sm" />
                <Botao variante="leve" className="py-1">Registrar</Botao>
              </form>
            </Cartao>
          );
        })}
      </div>
      <Cartao titulo="Novo projeto">
        {(clientes ?? []).length === 0 || (servicos ?? []).length === 0 ? (
          <Vazio>Pra criar projeto, cadastre antes um cliente e um serviço (em Ajustes).</Vazio>
        ) : (
          <form action={novoProjeto} className="grid gap-3 md:grid-cols-3">
            <Campo rotulo="Nome do projeto" name="nome" required placeholder="Ex.: Cozinha e sala, apto 1302" />
            <Escolha rotulo="Cliente" name="cliente_id" opcoes={clientes!} />
            <Escolha rotulo="Serviço" name="servico_id" opcoes={servicos!} />
            <Campo rotulo="Ambientes (separe por vírgula)" name="ambientes" />
            <Campo rotulo="Começa em" name="inicio" type="date" />
            <Botao className="self-end">Criar com as etapas</Botao>
          </form>
        )}
      </Cartao>
    </>
  );
}
