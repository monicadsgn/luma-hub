import { Menu } from "@/components/Menu";
import { contexto } from "@/lib/contexto";

export default async function LayoutHub({ children }: { children: React.ReactNode }) {
  const { papel, nome } = await contexto();
  return (
    <div className="mx-auto flex min-h-screen max-w-6xl flex-col gap-6 p-4 md:flex-row md:p-8">
      <aside className="md:w-52 md:shrink-0">
        <p className="mb-4 font-titulo text-xl text-marca">Luma Almeida</p>
        <Menu admin={papel === "admin"} />
        <p className="mt-6 hidden text-xs text-suave md:block">Entrou como {nome}</p>
      </aside>
      <main className="min-w-0 flex-1">{children}</main>
    </div>
  );
}
