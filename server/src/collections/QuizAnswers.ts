import type { CollectionConfig } from 'payload'

export const QuizAnswers: CollectionConfig = {
  slug: 'quiz-answers',
  admin: {
    useAsTitle: 'proposalId',
  },
  access: {
    read: () => true,
    create: ({ req }) => !!req.user,
    update: ({ req }) => !!req.user,
    delete: ({ req }) => !!req.user,
  },
  fields: [
    {
      name: 'proposalId',
      type: 'text',
      required: true,
      unique: true,
      index: true,
    },
    {
      name: 'answers',
      type: 'json',
      required: true,
    },
  ],
}
