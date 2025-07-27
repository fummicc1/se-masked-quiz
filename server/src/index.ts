import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { authRouter } from './routes/auth-cf';
import { quizActivitiesRouter } from './routes/quiz-activities-cf';
import type { Env } from './types/env';
import type { Variables } from './types/context';

const app = new Hono<{ Bindings: Env; Variables: Variables }>();

// Middleware
app.use('*', cors());
app.use('*', logger());

// Health check
app.get('/health', (c) => {
  return c.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    environment: 'cloudflare-workers'
  });
});

// Routes
app.route('/auth', authRouter);
app.route('/quiz-activities', quizActivitiesRouter);

// 404 handler
app.notFound((c) => {
  return c.json({ error: 'Not found' }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error('Server error:', err);
  return c.json({ error: 'Internal server error' }, 500);
});

export default app;