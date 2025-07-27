import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

export const users = sqliteTable('users', {
  id: text('id').primaryKey(),
  email: text('email'),
  emailVerified: integer('email_verified', { mode: 'boolean' }).default(false),
  isPrivateEmail: integer('is_private_email', { mode: 'boolean' }).default(false),
  realUserStatus: integer('real_user_status'),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull().$defaultFn(() => new Date()),
});

export const quizActivities = sqliteTable('quiz_activities', {
  id: text('id').primaryKey().$defaultFn(() => crypto.randomUUID()),
  userId: text('user_id').notNull().references(() => users.id),
  quizId: text('quiz_id').notNull(),
  score: integer('score').notNull(),
  totalQuestions: integer('total_questions').notNull(),
  correctAnswers: integer('correct_answers').notNull(),
  timeSpent: integer('time_spent').notNull(), // in seconds
  isNewRecord: integer('is_new_record', { mode: 'boolean' }).default(false),
  completedAt: integer('completed_at', { mode: 'timestamp' }).notNull(),
  createdAt: integer('created_at', { mode: 'timestamp' }).notNull().$defaultFn(() => new Date()),
  updatedAt: integer('updated_at', { mode: 'timestamp' }).notNull().$defaultFn(() => new Date()),
});

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type QuizActivity = typeof quizActivities.$inferSelect;
export type NewQuizActivity = typeof quizActivities.$inferInsert;