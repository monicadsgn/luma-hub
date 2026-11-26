// Formatos de tela. Sem regra de negócio aqui.

const real = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });

export const dinheiro = (centavos: number | null | undefined) => (centavos == null ? "—" : real.format(centavos / 100));

/** "1.234,56" ou "1234,5" → centavos. Vazio → null. Lixo → erro. */
export function paraCentavos(texto: string | null | undefined): number | null {
  const t = (texto ?? "").trim().replace(/^R\$\s*/, "");
  if (!t) return null;
  const normal = t.includes(",") ? t.replace(/\./g, "").replace(",", ".") : t;
  if (!/^\d+(\.\d{1,2})?$/.test(normal)) throw new Error("Valor inválido. Use só números, ex.: 1.500,00");
  return Math.round(Number(normal) * 100);
}

export function data(iso: string | null | undefined) {
  if (!iso) return "—";
  const [a, m, d] = iso.slice(0, 10).split("-");
  return `${d}/${m}/${a}`;
}

export function hora(iso: string) {
  return new Date(iso).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit", timeZone: "America/Recife" });
}

export function hojeISO(agora = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: "America/Recife" }).format(agora);
}
