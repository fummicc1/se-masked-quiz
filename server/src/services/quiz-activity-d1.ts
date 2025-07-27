import { eq, desc, and } from 'drizzle-orm';
import type { Database } from '../db';
import { quizActivities, type QuizActivity, type NewQuizActivity } from '../db/schema';

export class QuizActivityService {
  constructor(private db: Database) {}

  async createActivity(activity: Omit<NewQuizActivity, 'id' | 'createdAt' | 'updatedAt'>): Promise<QuizActivity> {
    // Check if this is a new record for the user and quiz
    const isNewRecord = await this.isNewRecord(
      activity.userId,
      activity.quizId,
      activity.score
    );

    const newActivity: NewQuizActivity = {
      ...activity,
      isNewRecord,
    };

    await this.db.insert(quizActivities).values(newActivity);

    const [createdActivity] = await this.db
      .select()
      .from(quizActivities)
      .where(
        and(
          eq(quizActivities.userId, activity.userId),
          eq(quizActivities.completedAt, activity.completedAt)
        )
      )
      .limit(1);

    return createdActivity;
  }

  async getUserActivities(userId: string, limit = 20): Promise<QuizActivity[]> {
    return await this.db
      .select()
      .from(quizActivities)
      .where(eq(quizActivities.userId, userId))
      .orderBy(desc(quizActivities.completedAt))
      .limit(limit);
  }

  async getRecentNewRecords(limit = 10): Promise<QuizActivity[]> {
    return await this.db
      .select()
      .from(quizActivities)
      .where(eq(quizActivities.isNewRecord, true))
      .orderBy(desc(quizActivities.completedAt))
      .limit(limit);
  }

  async getUserBestScores(userId: string): Promise<Map<string, QuizActivity>> {
    const activities = await this.db
      .select()
      .from(quizActivities)
      .where(eq(quizActivities.userId, userId))
      .orderBy(desc(quizActivities.score));

    const bestScores = new Map<string, QuizActivity>();
    
    for (const activity of activities) {
      if (!bestScores.has(activity.quizId)) {
        bestScores.set(activity.quizId, activity);
      } else {
        const current = bestScores.get(activity.quizId)!;
        if (activity.score > current.score) {
          bestScores.set(activity.quizId, activity);
        }
      }
    }

    return bestScores;
  }

  async getQuizBestScore(userId: string, quizId: string): Promise<QuizActivity | null> {
    const activities = await this.db
      .select()
      .from(quizActivities)
      .where(
        and(
          eq(quizActivities.userId, userId),
          eq(quizActivities.quizId, quizId)
        )
      )
      .orderBy(desc(quizActivities.score))
      .limit(1);

    return activities[0] || null;
  }

  private async isNewRecord(userId: string, quizId: string, score: number): Promise<boolean> {
    const bestScore = await this.getQuizBestScore(userId, quizId);
    return !bestScore || score > bestScore.score;
  }

  async getActivityById(id: string): Promise<QuizActivity | null> {
    const [activity] = await this.db
      .select()
      .from(quizActivities)
      .where(eq(quizActivities.id, id))
      .limit(1);

    return activity || null;
  }

  async getQuizLeaderboard(quizId: string, limit = 10): Promise<QuizActivity[]> {
    // Get best score for each user for this quiz
    const allActivities = await this.db
      .select()
      .from(quizActivities)
      .where(eq(quizActivities.quizId, quizId))
      .orderBy(desc(quizActivities.score));

    const userBestScores = new Map<string, QuizActivity>();
    
    for (const activity of allActivities) {
      if (!userBestScores.has(activity.userId) || 
          activity.score > userBestScores.get(activity.userId)!.score) {
        userBestScores.set(activity.userId, activity);
      }
    }

    return Array.from(userBestScores.values())
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);
  }

  async getGlobalLeaderboard(limit = 10): Promise<Array<{activity: QuizActivity, totalScore: number}>> {
    const allActivities = await this.db.select().from(quizActivities);
    
    // Calculate total best scores for each user
    const userBestActivities = new Map<string, QuizActivity[]>();
    
    for (const activity of allActivities) {
      if (!userBestActivities.has(activity.userId)) {
        userBestActivities.set(activity.userId, []);
      }
      
      const userActivities = userBestActivities.get(activity.userId)!;
      const existingIndex = userActivities.findIndex(a => a.quizId === activity.quizId);
      
      if (existingIndex === -1) {
        userActivities.push(activity);
      } else if (activity.score > userActivities[existingIndex].score) {
        userActivities[existingIndex] = activity;
      }
    }
    
    // Calculate total scores
    const results: Array<{activity: QuizActivity, totalScore: number}> = [];
    
    for (const [, activities] of userBestActivities.entries()) {
      const totalScore = activities.reduce((sum, activity) => sum + activity.score, 0);
      const bestActivity = activities.reduce((best, current) => 
        current.score > best.score ? current : best
      );
      results.push({ activity: bestActivity, totalScore });
    }
    
    return results
      .sort((a, b) => b.totalScore - a.totalScore)
      .slice(0, limit);
  }
}