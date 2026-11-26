import "server-only";
import { redirect } from "next/navigation";
import { connection } from "next/server";
import { bancoConfigurado, bancoDoUsuario } from "./supabase/servidor";

export type Contexto = {
  sb: Awaited<ReturnType<typeof bancoDoUsuario>>;
  org: string;
  papel: "admin" | "apoio";
  nome: string;
};

/** Quem está usando e de qual escritório. Sem login → /entrar. Sem convite → aviso. */
export async function contexto(): Promise<Contexto> {
  await connection(); // sempre na hora do acesso, nunca pré-montado
  if (!bancoConfigurado()) redirect("/entrar?motivo=sem-banco");
  const sb = await bancoDoUsuario();
  const { data: u } = await sb.auth.getUser();
  if (!u.user) redirect("/entrar");
  const { data: m } = await sb.from("membros").select("org_id, papel, nome").eq("user_id", u.user.id).eq("ativo", true).maybeSingle();
  if (!m) redirect("/entrar?motivo=sem-acesso");
  return { sb, org: m.org_id, papel: m.papel, nome: m.nome };
}
