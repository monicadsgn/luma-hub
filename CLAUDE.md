# Hub da Luma: regras do projeto

- Sistema da **Luma Almeida, arquiteta** (Recife e região). É o hub dela: CRM, clientes, projetos, tarefas,
  financeiro, propostas, contratos, portfólio do site e o conector do Claude.
- Sistema **próprio da Luma**. Não compartilha banco, deploy nem código em runtime com o SoftMoni, o Aden ou a
  Mônica Design. Eles são só referência de padrão. Nunca citar SoftMoni ou Aden em tela, PDF, texto de ajuda,
  skill ou conector.
- **Nenhum número de negócio no código**: preço, prazo, nº de alterações, % de sinal, validade. Tudo vem do que
  a Luma digita. Campos começam vazios (`null`). Nomes que ela disse podem ser sugestão, números nunca.
- **Nunca inventar dado do perfil dela** (anos de experiência, nº de clientes, depoimento, projeto). Faltou, avisa.
- **Contrato**: o texto das cláusulas é da Luma (`modelos_documento`). Nem o sistema nem o Claude escrevem
  cláusula por conta própria.
- Dinheiro em centavos (inteiro). Percentuais de 0 a 100.
- Toda tabela nova: `org_id` + `select preparar_tabela('<tabela>', 'membro'|'admin')` (RLS + carimbo + histórico).
  Valor em dinheiro = leitura `admin` (quem é "apoio" não vê).
- Site público só lê por funções (`portfolio_publico`, `site_publico`) e só escreve pelo pré-briefing
  (`/api/pre-briefing` → `pre_briefing_*`, com segredo). Nunca liberar tabela para `anon`.
- Portfólio: só aparece no site o que está **publicado e autorizado**.
- **Todo botão do site leva ao pré-briefing.** Guardar qual botão foi (`botao_origem`).
- A Luma tem pouco tempo e só mexe à noite. Telas curtas, uma coisa por tela, nada de etapa a mais.
- Linguagem: direta e literal, frases curtas, sem travessão. Dizer "criativos", nunca "artes".
  Para o cliente final: "conversa inicial" no lugar de briefing.
- Conector MCP (`/api/mcp/[codigo]`): toda área nova ganha ferramenta no conector. O que o Claude grava fica no
  histórico como "pelo Claude" (`set_config('luma.pelo_claude','sim', true)`).
- Mudou o schema → nova migration numerada (nunca editar uma que já foi aplicada) e rodar `scripts/testar_schema.sh`.
- Next.js 16: ler `node_modules/next/dist/docs/` antes de usar API nova (`middleware` virou `proxy`).
