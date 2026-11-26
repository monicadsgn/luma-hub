import { redirect } from "next/navigation";
import { Botao, Campo, Cartao, Escolha, Selo, Titulo, Vazio } from "@/components/ui";
import { marcarPago, novoLancamento } from "@/lib/acoes";
import { contexto } from "@/lib/contexto";
import { data, dinheiro, hojeISO } from "@/lib/formato";

type Resumo = { entrou_centavos: number; saiu_centavos: number; falta_receber_centavos: number; falta_pagar_centavos: number; atrasados: number };
type Lanc = { id: string; tipo: string; descricao: string; valor_centavos: number; vencimento: string; status: string; clientes: { nome: string } | null };

export default async function Financeiro() {
  const { sb, org, papel } = await contexto();
  if (papel !== "admin") redirect("/hoje");
  const hoje = hojeISO();
  const [{ data: r }, { data: l, error }, { data: clientes }] = await Promise.all([
    sb.rpc("resumo_financeiro", { p_org: org, p_mes: hoje }),
    sb.from("lancamentos").select("id, tipo, descricao, valor_centavos, vencimento, status, clientes(nome)").neq("status", "cancelado")
      .gte("vencimento", hoje.slice(0, 8) + "01").order("vencimento").limit(200),
    sb.from("clientes").select("id, nome").eq("ativo", true).order("nome"),
  ]);
  if (error) throw new Error(error.message);
  const res = r as Resumo | null;
  const lista = (l ?? []) as unknown as Lanc[];

  return (
    <>
      <Titulo explica="O que entrou, o que saiu e o que ainda vai entrar ou sair neste mês. Só você vê.">Financeiro</Titulo>
      {res && (
        <div className="mb-6 grid grid-cols-2 gap-3 md:grid-cols-4">
          <Cartao><p className="text-xl font-titulo">{dinheiro(res.entrou_centavos)}</p><p className="text-sm">Entrou</p></Cartao>
          <Cartao><p className="text-xl font-titulo">{dinheiro(res.saiu_centavos)}</p><p className="text-sm">Saiu</p></Cartao>
          <Cartao><p className="text-xl font-titulo">{dinheiro(res.falta_receber_centavos)}</p><p className="text-sm">Falta receber</p></Cartao>
          <Cartao><p className="text-xl font-titulo">{dinheiro(res.falta_pagar_centavos)}</p><p className="text-sm">Falta pagar</p>
            {res.atrasados > 0 && <p className="text-xs text-aviso">{res.atrasados} em atraso</p>}</Cartao>
        </div>
      )}
      <Cartao titulo="Deste mês em diante" className="mb-6">
        {lista.length === 0 ? <Vazio>Nada lançado.</Vazio> : (
          <ul className="flex flex-col divide-y divide-linha text-sm">
            {lista.map((x) => (
              <li key={x.id} className="flex flex-wrap items-center gap-3 py-2">
                <span className="w-20 text-suave">{data(x.vencimento)}</span>
                <span className="flex-1">{x.descricao}{x.clientes ? ` · ${x.clientes.nome}` : ""}</span>
                <span className={x.tipo === "entrada" ? "text-ok" : "text-texto"}>{x.tipo === "entrada" ? "+" : "−"} {dinheiro(x.valor_centavos)}</span>
                {x.status === "pago" ? <Selo tom="ok">Pago</Selo> : (
                  <form action={marcarPago}><input type="hidden" name="id" value={x.id} /><Botao variante="leve" className="px-3 py-1">Marcar pago</Botao></form>
                )}
              </li>
            ))}
          </ul>
        )}
      </Cartao>
      <Cartao titulo="Lançar">
        <form action={novoLancamento} className="grid gap-3 md:grid-cols-3">
          <Escolha rotulo="Tipo" name="tipo" opcoes={[{ id: "entrada", nome: "Entrada" }, { id: "saida", nome: "Saída" }]} />
          <Campo rotulo="Descrição" name="descricao" required />
          <Campo rotulo="Valor (R$)" name="valor" required inputMode="decimal" placeholder="0,00" />
          <Campo rotulo="Vencimento" name="vencimento" type="date" required defaultValue={hoje} />
          <Escolha rotulo="Cliente (opcional)" name="cliente_id" opcoes={[{ id: "", nome: "—" }, ...(clientes ?? [])]} />
          <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="pago" /> Já foi pago</label>
          <Botao className="md:col-start-3">Lançar</Botao>
        </form>
      </Cartao>
    </>
  );
}
