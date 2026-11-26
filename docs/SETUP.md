# Colocar no ar

Contas exclusivas da Luma: organização "Luma Almeida" no Supabase (criada em 26/11/2026). Não usar o
projeto Supabase de outro sistema.

## 1. Supabase
1. Projeto `luma-hub`, região São Paulo (sa-east-1).
2. Rodar as migrations de `supabase/migrations/` em ordem.
3. Authentication → Users: criar o usuário da Luma (e o de apoio, se houver).
4. SQL Editor:
   ```sql
   insert into organizacoes (nome) values ('Luma Almeida') returning id;
   insert into membros (org_id, user_id, nome, email, papel)
     select '<ORG>', id, 'Luma', email, 'admin' from auth.users where email = '<email da Luma>';
   select pre_briefing_configurar('<ORG>', '<um segredo longo>');
   ```
5. Ou, no lugar do passo 4: `supabase/primeiro_acesso.sql` (troque só o e-mail). Faz tudo de uma vez.

## 2. Vercel
Importar `monicadsgn/luma-hub` e cadastrar as variáveis de `.env.example`
(`PRE_BRIEFING_SEGREDO` = o mesmo segredo do passo 4). Mexeu em variável → Redeploy.
