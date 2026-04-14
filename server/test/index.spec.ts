import { describe, it, expect } from 'vitest'

describe('Payload CMS Configuration', () => {
  it('collections are defined', async () => {
    const { Proposals } = await import('../src/collections/Proposals')
    const { QuizAnswers } = await import('../src/collections/QuizAnswers')
    const { Users } = await import('../src/collections/Users')

    expect(Proposals.slug).toBe('proposals')
    expect(QuizAnswers.slug).toBe('quiz-answers')
    expect(Users.slug).toBe('users')
  })

  it('Proposals collection has required fields', async () => {
    const { Proposals } = await import('../src/collections/Proposals')
    const fieldNames = Proposals.fields.map((f) => ('name' in f ? f.name : ''))
    expect(fieldNames).toContain('proposalId')
    expect(fieldNames).toContain('title')
    expect(fieldNames).toContain('authors')
    expect(fieldNames).toContain('content')
    expect(fieldNames).toContain('reviewManager')
    expect(fieldNames).toContain('status')
  })

  it('QuizAnswers collection has required fields', async () => {
    const { QuizAnswers } = await import('../src/collections/QuizAnswers')
    const fieldNames = QuizAnswers.fields.map((f) => ('name' in f ? f.name : ''))
    expect(fieldNames).toContain('proposalId')
    expect(fieldNames).toContain('answers')
  })

  it('Users collection has API key auth enabled', async () => {
    const { Users } = await import('../src/collections/Users')
    expect(Users.auth).toEqual({ useAPIKey: true })
  })
})
