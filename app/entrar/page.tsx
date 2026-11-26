"use client";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { Botao, Campo } from "@/components/ui";
import { bancoNoNavegador } from "@/lib/supabase/navegador";

const MOTIVOS: Record<string, string> = {
  "sem-banco": "O sistema ainda não está ligado ao banco de dados.",
  "sem-acesso": "Este e-mail ainda não tem acesso. Peça o convite.",
};

function Formulario() {
  const router = useRouter();
  const motivo = useSearchParams().get("motivo");
  const [erro, setErro] = useState<string | null>(motivo ? MOTIVOS[motivo] ?? null : null);
  const [enviando, setEnviando] = useState(false);

  return (
    <form className="w-full max-w-sm rounded-card border border-linha bg-superficie p-8"
      onSubmit={async (e) => {
        e.preventDefault();
        const f = new FormData(e.currentTarget);
        setEnviando(true);
        setErro(null);
        const { error } = await bancoNoNavegador().auth.signInWithPassword({ email: String(f.get("email")), password: String(f.get("senha")) });
        setEnviando(false);
        if (error) return setErro("E-mail ou senha não conferem.");
        router.replace("/hoje");
        router.refresh();
      }}>
      <p className="font-titulo text-2xl text-marca">Luma Almeida</p>
      <h1 className="mt-4 text-xl">Entrar</h1>
      <div className="mt-6 flex flex-col gap-3">
        <Campo rotulo="E-mail" name="email" type="email" required autoComplete="email" />
        <Campo rotulo="Senha" name="senha" type="password" required autoComplete="current-password" />
        {erro && <p className="text-sm text-erro">{erro}</p>}
        <Botao disabled={enviando}>{enviando ? "Entrando..." : "Entrar"}</Botao>
      </div>
    </form>
  );
}

export default function Entrar() {
  return (
    <div className="flex min-h-screen items-center justify-center p-4">
      <Suspense><Formulario /></Suspense>
    </div>
  );
}
