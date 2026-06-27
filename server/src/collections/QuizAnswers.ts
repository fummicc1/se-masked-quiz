import type { CollectionConfig } from 'payload'

const PROPOSAL_ID_PATTERN = /^\d{4}$/
const MAX_ANSWERS = 1000
const MAX_OPTIONS_PER_ANSWER = 50
const MAX_STRING_LENGTH = 2000

const isQuizAnswerShape = (entry: unknown): entry is Record<string, unknown> => {
  if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) return false
  const record = entry as Record<string, unknown>
  if (typeof record.index !== 'number' || !Number.isInteger(record.index) || record.index < 0) {
    return false
  }
  if (typeof record.answer !== 'string' || record.answer.length > MAX_STRING_LENGTH) {
    return false
  }
  if (!Array.isArray(record.options) || record.options.length > MAX_OPTIONS_PER_ANSWER) {
    return false
  }
  return record.options.every(
    (option) => typeof option === 'string' && option.length <= MAX_STRING_LENGTH,
  )
}

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
      validate: (value: unknown) => {
        if (typeof value !== 'string' || !PROPOSAL_ID_PATTERN.test(value)) {
          return 'proposalId must be four digits (e.g. 0001)'
        }
        return true
      },
    },
    {
      name: 'answers',
      type: 'json',
      required: true,
      validate: (value: unknown) => {
        if (!Array.isArray(value)) {
          return 'answers must be an array of QuizAnswer objects'
        }
        if (value.length > MAX_ANSWERS) {
          return `answers must contain at most ${MAX_ANSWERS} entries`
        }
        if (!value.every(isQuizAnswerShape)) {
          return 'each answer must have { index: integer, answer: string, options: string[] }'
        }
        return true
      },
    },
  ],
}
