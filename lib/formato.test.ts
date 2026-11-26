import { describe, expect, it } from "vitest";
import { data, dinheiro, hojeISO, paraCentavos } from "./formato";

describe("formato", () => {
  it("converte texto em centavos", () => {
    expect(paraCentavos("1.500,00")).toBe(150000);
    expect(paraCentavos("R$ 99,9")).toBe(9990);
    expect(paraCentavos("250")).toBe(25000);
    expect(paraCentavos("")).toBeNull();
    expect(() => paraCentavos("abc")).toThrow();
  });
  it("mostra dinheiro e data", () => {
    expect(dinheiro(150000).replace(/\s/g, " ")).toBe("R$ 1.500,00");
    expect(dinheiro(null)).toBe("—");
    expect(data("2026-12-14")).toBe("14/12/2026");
  });
  it("usa o dia de Recife", () => {
    expect(hojeISO(new Date("2026-11-27T02:00:00Z"))).toBe("2026-11-26");
  });
});
