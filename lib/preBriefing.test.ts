import { describe, expect, it } from "vitest";
import { lerPedido } from "./preBriefing";

const sessao = "aaaaaaaa-0000-4000-8000-000000000001";

describe("pré-briefing", () => {
  it("aceita envio válido e converte a metragem", () => {
    const p = lerPedido({ acao: "enviar", dados: { nome: "Ana", telefone: "(81) 99999-0000", metragem_m2: "52,5", ambientes: ["cozinha"] } });
    expect(p.acao).toBe("enviar");
    if (p.acao === "enviar") { expect(p.dados.metragem_m2).toBe(52.5); expect(p.robo).toBe(false); }
  });
  it("recusa sem nome ou sem DDD", () => {
    expect(() => lerPedido({ acao: "enviar", dados: { nome: "", telefone: "81999990000" } })).toThrow("Informe seu nome.");
    expect(() => lerPedido({ acao: "enviar", dados: { nome: "Ana", telefone: "99990000" } })).toThrow("DDD");
  });
  it("marca robô pela armadilha", () => {
    const p = lerPedido({ acao: "enviar", dados: { nome: "Ana", telefone: "81999990000", site: "http://spam" } });
    expect(p.acao === "enviar" && p.robo).toBe(true);
  });
  it("aceita passo", () => {
    expect(lerPedido({ acao: "passo", sessao, passo: "servico" }).acao).toBe("passo");
    expect(() => lerPedido({ acao: "passo", sessao: "x", passo: "servico" })).toThrow();
  });
});
