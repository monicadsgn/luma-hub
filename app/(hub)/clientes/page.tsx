import { Botao, Campo, Cartao, Titulo, Vazio } from "@/components/ui";
import { novoCliente } from "@/lib/acoes";
import { contexto } from "@/lib/contexto";
import { nomeOrigem } from "@/lib/rotulos";

type Cliente = { id: string; nome: string; telefone: string | null; cidade: string | null; origem: string | null; projetos: { id: string; nome: string; status: string }[] };

export default async function Clientes() {
  const { sb } = await contexto();
  const { data, error } = await sb.from("clientes").select("id, nome, telefone, cidade, origem, projetos(id, nome, status)").eq("ativo", true).order("nome");
  if (error) throw new Error(error.message);
  const lista = (data ?? []) as Cliente[];
  return (
    <>
      <Titulo explica="Cada cliente com os projetos dele. Quem fecha no CRM entra aqui sozinho.">Clientes</Titulo>
      <Cartao className="mb-6">
        {lista.length === 0 ? <Vazio>Nenhum cliente ainda.</Vazio> : (
          <ul className="flex flex-col divide-y divide-linha text-sm">
            {lista.map((c) => (
              <li key={c.id} className="py-3">
                <p className="font-medium">{c.nome}</p>
                <p className="text-suave">{[c.telefone, c.cidade, c.origem && nomeOrigem(c.origem)].filter(Boolean).join(" · ") || "—"}</p>
                {c.projetos.length > 0 && <p className="mt-1">{c.projetos.map((p) => p.nome).join(", ")}</p>}
              </li>
            ))}
          </ul>
        )}
      </Cartao>
      <Cartao titulo="Novo cliente">
        <form action={novoCliente} className="grid gap-3 md:grid-cols-4">
          <Campo rotulo="Nome" name="nome" required />
          <Campo rotulo="WhatsApp" name="telefone" />
          <Campo rotulo="E-mail" name="email" type="email" />
          <Campo rotulo="Cidade" name="cidade" />
          <Botao className="md:col-start-4">Guardar</Botao>
        </form>
      </Cartao>
    </>
  );
}
