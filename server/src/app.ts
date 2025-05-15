import { Hono } from 'hono';
import { createClient, SupabaseClient } from '@supabase/supabase-js'; 
import { authRouter } from './routes/auth';
import { cors } from 'hono/cors';
import { Bindings } from './types'; // Bindingsを正しくインポート
import { PrismaClient } from '@prisma/client';
import { debugRouter } from './routes/debug';
import { PrismaPg } from '@prisma/adapter-pg';

// ローカルの Bindings 型定義は削除されました

declare module 'hono' {
  interface ContextVariableMap {
    prisma: PrismaClient;
    supabase: SupabaseClient;
  }
}

export const app = new Hono<{ Bindings: Bindings }>();

app.use('*', cors());

app.use('*', async (c, next) => {
  console.log(c.env.DATABASE_URL);
  const connectionString = String(c.env.DATABASE_URL);
  const adapter = new PrismaPg({connectionString});
  const prisma = new PrismaClient({ adapter });

  console.log(c.env.SUPABASE_URL);
  const supabase = createClient(
    c.env.SUPABASE_URL,
    c.env.SUPABASE_KEY
  );
  c.set('prisma', prisma);
  c.set('supabase', supabase);
  await next();
  await prisma.$disconnect();
});

app.route('/api/auth', authRouter);
app.route('/api/debug', debugRouter);

app.get('/', (c) => c.json({ status: 'ok', message: 'SE Masked Quiz API' }));
