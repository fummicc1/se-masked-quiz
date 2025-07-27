import { Hono } from 'hono';
import { z } from 'zod';
import { authMiddleware } from '../middleware/auth-cf';
import { QuizActivityService } from '../services/quiz-activity-d1';
import { createDb } from '../db';
import type { Env } from '../types/env';
import type { Variables } from '../types/context';

const quizActivitiesRouter = new Hono<{ Bindings: Env; Variables: Variables }>();

// Request validation schemas
const createActivitySchema = z.object({
  quizId: z.string(),
  score: z.number().int().min(0),
  totalQuestions: z.number().int().min(1),
  correctAnswers: z.number().int().min(0),
  timeSpent: z.number().int().min(0), // in seconds
  completedAt: z.string().datetime().or(z.date()).transform(val => new Date(val)),
});

const paginationSchema = z.object({
  limit: z.string().transform(Number).pipe(z.number().int().min(1).max(100)).optional(),
});

// POST /quiz-activities - Create a new quiz activity
quizActivitiesRouter.post('/', authMiddleware, async (c) => {
  try {
    const userId = c.get('userId');
    const body = await c.req.json();
    const validatedData = createActivitySchema.parse(body);

    // Validate correctAnswers <= totalQuestions
    if (validatedData.correctAnswers > validatedData.totalQuestions) {
      return c.json({ 
        error: 'Correct answers cannot be greater than total questions' 
      }, 400);
    }

    const db = createDb(c.env.DB);
    const quizActivityService = new QuizActivityService(db);

    const activity = await quizActivityService.createActivity({
      userId,
      ...validatedData,
    });

    return c.json({
      success: true,
      activity: {
        id: activity.id,
        quizId: activity.quizId,
        score: activity.score,
        totalQuestions: activity.totalQuestions,
        correctAnswers: activity.correctAnswers,
        timeSpent: activity.timeSpent,
        isNewRecord: activity.isNewRecord,
        completedAt: activity.completedAt,
        createdAt: activity.createdAt,
      },
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return c.json({ error: 'Invalid request data', details: error.errors }, 400);
    }
    
    console.error('Create activity error:', error);
    return c.json({ error: 'Failed to create activity' }, 500);
  }
});

// GET /quiz-activities/user/:userId - Get user's activities
quizActivitiesRouter.get('/user/:userId', authMiddleware, async (c) => {
  try {
    const { userId } = c.req.param();
    const { limit } = paginationSchema.parse(c.req.query());

    const db = createDb(c.env.DB);
    const quizActivityService = new QuizActivityService(db);

    const activities = await quizActivityService.getUserActivities(userId, limit);

    return c.json({
      success: true,
      activities: activities.map(activity => ({
        id: activity.id,
        quizId: activity.quizId,
        score: activity.score,
        totalQuestions: activity.totalQuestions,
        correctAnswers: activity.correctAnswers,
        timeSpent: activity.timeSpent,
        isNewRecord: activity.isNewRecord,
        completedAt: activity.completedAt,
        createdAt: activity.createdAt,
      })),
    });
  } catch (error) {
    console.error('Get user activities error:', error);
    return c.json({ error: 'Failed to get activities' }, 500);
  }
});

// GET /quiz-activities/recent - Get recent new records (public endpoint)
quizActivitiesRouter.get('/recent', async (c) => {
  try {
    const { limit } = paginationSchema.parse(c.req.query());

    const db = createDb(c.env.DB);
    const quizActivityService = new QuizActivityService(db);

    const activities = await quizActivityService.getRecentNewRecords(limit);

    return c.json({
      success: true,
      activities: activities.map(activity => ({
        id: activity.id,
        userId: activity.userId,
        quizId: activity.quizId,
        score: activity.score,
        totalQuestions: activity.totalQuestions,
        correctAnswers: activity.correctAnswers,
        timeSpent: activity.timeSpent,
        completedAt: activity.completedAt,
      })),
    });
  } catch (error) {
    console.error('Get recent records error:', error);
    return c.json({ error: 'Failed to get recent records' }, 500);
  }
});

// GET /quiz-activities/best-scores/:userId - Get user's best scores
quizActivitiesRouter.get('/best-scores/:userId', authMiddleware, async (c) => {
  try {
    const { userId } = c.req.param();

    const db = createDb(c.env.DB);
    const quizActivityService = new QuizActivityService(db);

    const bestScores = await quizActivityService.getUserBestScores(userId);

    const result = Array.from(bestScores.entries()).map(([quizId, activity]) => ({
      quizId,
      bestScore: activity.score,
      totalQuestions: activity.totalQuestions,
      correctAnswers: activity.correctAnswers,
      timeSpent: activity.timeSpent,
      completedAt: activity.completedAt,
    }));

    return c.json({
      success: true,
      bestScores: result,
    });
  } catch (error) {
    console.error('Get best scores error:', error);
    return c.json({ error: 'Failed to get best scores' }, 500);
  }
});

// GET /quiz-activities/leaderboard/:quizId - Get quiz leaderboard
quizActivitiesRouter.get('/leaderboard/:quizId', async (c) => {
  try {
    const { quizId } = c.req.param();
    const { limit } = paginationSchema.parse(c.req.query());

    const db = createDb(c.env.DB);
    const quizActivityService = new QuizActivityService(db);

    const leaderboard = await quizActivityService.getQuizLeaderboard(quizId, limit);

    return c.json({
      success: true,
      leaderboard: leaderboard.map((activity, index) => ({
        rank: index + 1,
        userId: activity.userId,
        score: activity.score,
        totalQuestions: activity.totalQuestions,
        correctAnswers: activity.correctAnswers,
        timeSpent: activity.timeSpent,
        completedAt: activity.completedAt,
      })),
    });
  } catch (error) {
    console.error('Get leaderboard error:', error);
    return c.json({ error: 'Failed to get leaderboard' }, 500);
  }
});

// GET /quiz-activities/global-leaderboard - Get global leaderboard
quizActivitiesRouter.get('/global-leaderboard', async (c) => {
  try {
    const { limit } = paginationSchema.parse(c.req.query());

    const db = createDb(c.env.DB);
    const quizActivityService = new QuizActivityService(db);

    const leaderboard = await quizActivityService.getGlobalLeaderboard(limit);

    return c.json({
      success: true,
      leaderboard: leaderboard.map((entry, index) => ({
        rank: index + 1,
        userId: entry.activity.userId,
        totalScore: entry.totalScore,
        lastActivity: {
          quizId: entry.activity.quizId,
          score: entry.activity.score,
          completedAt: entry.activity.completedAt,
        },
      })),
    });
  } catch (error) {
    console.error('Get global leaderboard error:', error);
    return c.json({ error: 'Failed to get global leaderboard' }, 500);
  }
});

// GET /quiz-activities/:id - Get single activity
quizActivitiesRouter.get('/:id', authMiddleware, async (c) => {
  try {
    const { id } = c.req.param();

    const db = createDb(c.env.DB);
    const quizActivityService = new QuizActivityService(db);

    const activity = await quizActivityService.getActivityById(id);

    if (!activity) {
      return c.json({ error: 'Activity not found' }, 404);
    }

    return c.json({
      success: true,
      activity: {
        id: activity.id,
        userId: activity.userId,
        quizId: activity.quizId,
        score: activity.score,
        totalQuestions: activity.totalQuestions,
        correctAnswers: activity.correctAnswers,
        timeSpent: activity.timeSpent,
        isNewRecord: activity.isNewRecord,
        completedAt: activity.completedAt,
        createdAt: activity.createdAt,
      },
    });
  } catch (error) {
    console.error('Get activity error:', error);
    return c.json({ error: 'Failed to get activity' }, 500);
  }
});

export { quizActivitiesRouter };