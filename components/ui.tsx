// Peças de tela. Só tokens de app/globals.css (bg-marca, text-suave, rounded-card...).
import type { ComponentProps, ReactNode } from "react";

export function Titulo({ children, explica }: { children: ReactNode; explica?: string }) {
  return (
    <header className="mb-6">
      <h1 className="text-3xl text-texto">{children}</h1>
      {explica && <p className="mt-1 text-sm text-suave">{explica}</p>}
    </header>
  );
}

export function Cartao({ titulo, children, className = "" }: { titulo?: string; children: ReactNode; className?: string }) {
  return (
    <section className={`rounded-card border border-linha bg-superficie p-5 ${className}`}>
      {titulo && <h2 className="mb-3 text-lg">{titulo}</h2>}
      {children}
    </section>
  );
}

export function Vazio({ children }: { children: ReactNode }) {
  return <p className="text-sm text-suave">{children}</p>;
}

export function Botao({ variante = "cheio", className = "", ...p }: ComponentProps<"button"> & { variante?: "cheio" | "leve" }) {
  const estilo =
    variante === "cheio"
      ? "bg-marca text-fundo hover:bg-marca-forte"
      : "border border-linha bg-superficie text-texto hover:bg-areia-suave";
  return <button className={`rounded-card px-4 py-2 text-sm font-medium transition ${estilo} ${className}`} {...p} />;
}

export function Campo({ rotulo, className = "", ...p }: ComponentProps<"input"> & { rotulo: string }) {
  return (
    <label className={`flex flex-col gap-1 text-sm ${className}`}>
      <span className="text-suave">{rotulo}</span>
      <input className="rounded-card border border-linha bg-fundo px-3 py-2 text-texto" {...p} />
    </label>
  );
}

export function Escolha({ rotulo, opcoes, className = "", ...p }: ComponentProps<"select"> & { rotulo: string; opcoes: { id: string; nome: string }[] }) {
  return (
    <label className={`flex flex-col gap-1 text-sm ${className}`}>
      <span className="text-suave">{rotulo}</span>
      <select className="rounded-card border border-linha bg-fundo px-3 py-2 text-texto" {...p}>
        {opcoes.map((o) => (
          <option key={o.id} value={o.id}>{o.nome}</option>
        ))}
      </select>
    </label>
  );
}

export function Selo({ children, tom = "neutro" }: { children: ReactNode; tom?: "neutro" | "marca" | "aviso" | "ok" | "erro" }) {
  const cor = { neutro: "bg-areia-suave text-suave", marca: "bg-areia-suave text-marca-forte", aviso: "bg-areia-suave text-aviso", ok: "bg-areia-suave text-ok", erro: "bg-areia-suave text-erro" }[tom];
  return <span className={`rounded-card px-2 py-0.5 text-xs font-medium ${cor}`}>{children}</span>;
}
