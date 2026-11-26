"use client";
import { CalendarCheck, CheckSquare, FolderKanban, Settings, Users, Wallet, Inbox } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

const ITENS = [
  { href: "/hoje", nome: "Hoje", icone: CalendarCheck, admin: false },
  { href: "/crm", nome: "Quem chegou", icone: Inbox, admin: false },
  { href: "/clientes", nome: "Clientes", icone: Users, admin: false },
  { href: "/projetos", nome: "Projetos", icone: FolderKanban, admin: false },
  { href: "/tarefas", nome: "Tarefas", icone: CheckSquare, admin: false },
  { href: "/financeiro", nome: "Financeiro", icone: Wallet, admin: true },
  { href: "/ajustes", nome: "Ajustes", icone: Settings, admin: true },
];

export function Menu({ admin }: { admin: boolean }) {
  const atual = usePathname();
  return (
    <nav className="flex gap-1 overflow-x-auto md:flex-col">
      {ITENS.filter((i) => admin || !i.admin).map(({ href, nome, icone: Icone }) => {
        const ativo = atual.startsWith(href);
        return (
          <Link key={href} href={href}
            className={`flex shrink-0 items-center gap-2 rounded-card px-3 py-2 text-sm ${ativo ? "bg-areia-suave text-marca-forte font-medium" : "text-suave hover:bg-areia-suave"}`}>
            <Icone size={18} /> {nome}
          </Link>
        );
      })}
    </nav>
  );
}
