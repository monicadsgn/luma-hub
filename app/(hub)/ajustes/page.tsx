import { redirect } from "next/navigation";
import { Botao, Campo, Cartao, Titulo } from "@/components/ui";
import { salvarEstudio, salvarServico } from "@/lib/acoes";
import { contexto } from "@/lib/contexto";

const CAMPOS: [string, string][] = [
  ["nome_publico", "Nome no site e nos documentos"], ["nome_contrato", "Nome no contrato"], ["documento", "CPF ou CNPJ"],
  ["registro_cau", "Registro no CAU"], ["endereco", "Endereço"], ["cidade", "Cidade"], ["whatsapp", "WhatsApp"],
  ["email", "E-mail"], ["instagram", "Instagram"], ["pix", "Chave PIX"],
];

type Servico = { id: string; nome: string; descricao_cliente: string | null; prazo_dias_uteis: number | null; limite_alteracoes: number | null; aparece_no_site: boolean };

export default async function Ajustes() {
  const { sb, org, papel } = await contexto();
  if (papel !== "admin") redirect("/hoje");
  const [{ data: e }, { data: s }] = await Promise.all([
    sb.from("estudio").select("*").eq("org_id", org).maybeSingle(),
    sb.from("servicos").select("id, nome, descricao_cliente, prazo_dias_uteis, limite_alteracoes, aparece_no_site").order("ordem"),
  ]);
  const est = (e ?? {}) as Record<string, string | number | null>;
  const servicos = (s ?? []) as Servico[];

  return (
    <>
      <Titulo explica="Preencha uma vez. Isso vai na proposta, no contrato e no site.">Ajustes</Titulo>
      <Cartao titulo="Seus dados" className="mb-6">
        <form action={salvarEstudio} className="grid gap-3 md:grid-cols-2">
          {CAMPOS.map(([k, r]) => <Campo key={k} rotulo={r} name={k} defaultValue={(est[k] as string) ?? ""} />)}
          <Campo rotulo="Proposta vale por quantos dias" name="validade_proposta_dias" type="number" min={1} defaultValue={(est.validade_proposta_dias as number) ?? ""} />
          <Campo rotulo="Avisar lead parado depois de quantos dias" name="dias_lead_parado" type="number" min={1} defaultValue={(est.dias_lead_parado as number) ?? ""} />
          <Botao className="md:col-start-2">Salvar</Botao>
        </form>
      </Cartao>
      <Cartao titulo="Serviços">
        <p className="mb-4 text-sm text-suave">Prazo e número de alterações ficam vazios até você preencher. Eles entram na proposta e no projeto.</p>
        <div className="flex flex-col gap-4">
          {[...servicos, null].map((sv) => (
            <form key={sv?.id ?? "novo"} action={salvarServico} className="grid gap-3 border-t border-linha pt-4 md:grid-cols-4">
              {sv && <input type="hidden" name="id" value={sv.id} />}
              <Campo rotulo={sv ? "Serviço" : "Novo serviço"} name="nome" required defaultValue={sv?.nome ?? ""} />
              <Campo rotulo="Como explicar pro cliente" name="descricao_cliente" defaultValue={sv?.descricao_cliente ?? ""} className="md:col-span-3" />
              <Campo rotulo="Prazo (dias úteis)" name="prazo_dias_uteis" type="number" min={1} defaultValue={sv?.prazo_dias_uteis ?? ""} />
              <Campo rotulo="Alterações incluídas" name="limite_alteracoes" type="number" min={0} defaultValue={sv?.limite_alteracoes ?? ""} />
              <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="aparece_no_site" defaultChecked={sv?.aparece_no_site ?? false} /> Aparece no site</label>
              <Botao variante={sv ? "leve" : "cheio"}>{sv ? "Salvar" : "Adicionar"}</Botao>
            </form>
          ))}
        </div>
      </Cartao>
    </>
  );
}
