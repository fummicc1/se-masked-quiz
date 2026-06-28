import { describe, it, expect } from 'vitest';

describe('Payload CMS Configuration', () => {
	it('collections are defined', async () => {
		const { Proposals } = await import('../src/collections/Proposals');
		const { QuizAnswers } = await import('../src/collections/QuizAnswers');
		const { Users } = await import('../src/collections/Users');

		expect(Proposals.slug).toBe('proposals');
		expect(QuizAnswers.slug).toBe('quiz-answers');
		expect(Users.slug).toBe('users');
	});

	it('Proposals collection has required fields', async () => {
		const { Proposals } = await import('../src/collections/Proposals');
		const fieldNames = Proposals.fields.map((f) => ('name' in f ? f.name : ''));
		expect(fieldNames).toContain('proposalId');
		expect(fieldNames).toContain('title');
		expect(fieldNames).toContain('authors');
		expect(fieldNames).toContain('content');
		expect(fieldNames).toContain('reviewManager');
		expect(fieldNames).toContain('status');
	});

	it('QuizAnswers collection has required fields', async () => {
		const { QuizAnswers } = await import('../src/collections/QuizAnswers');
		const fieldNames = QuizAnswers.fields.map((f) => ('name' in f ? f.name : ''));
		expect(fieldNames).toContain('proposalId');
		expect(fieldNames).toContain('answers');
	});

	it('Users collection has API key auth enabled', async () => {
		const { Users } = await import('../src/collections/Users');
		expect(Users.auth).toEqual({ useAPIKey: true });
	});

	it('ProposalReferences collection has from/to fields', async () => {
		const { ProposalReferences } = await import('../src/collections/ProposalReferences');
		expect(ProposalReferences.slug).toBe('proposal-references');
		const fieldNames = ProposalReferences.fields.map((f) => ('name' in f ? f.name : ''));
		expect(fieldNames).toContain('fromProposalId');
		expect(fieldNames).toContain('toProposalId');
	});

	it('ProposalReferences validates four-digit ids', async () => {
		const { ProposalReferences } = await import('../src/collections/ProposalReferences');
		const field = ProposalReferences.fields.find((f) => 'name' in f && f.name === 'fromProposalId') as {
			validate: (value: unknown) => true | string;
		};
		expect(field.validate('0001')).toBe(true);
		expect(typeof field.validate('SE-1')).toBe('string');
		expect(typeof field.validate('12')).toBe('string');
		expect(typeof field.validate(1234)).toBe('string');
	});

	it('TestingProposals collection has required fields', async () => {
		const { TestingProposals } = await import('../src/collections/TestingProposals');
		expect(TestingProposals.slug).toBe('testing-proposals');
		const fieldNames = TestingProposals.fields.map((f) => ('name' in f ? f.name : ''));
		expect(fieldNames).toContain('proposalId');
		expect(fieldNames).toContain('title');
		expect(fieldNames).toContain('content');
	});

	it('TestingQuizAnswers collection has required fields', async () => {
		const { TestingQuizAnswers } = await import('../src/collections/TestingQuizAnswers');
		expect(TestingQuizAnswers.slug).toBe('testing-quiz-answers');
		const fieldNames = TestingQuizAnswers.fields.map((f) => ('name' in f ? f.name : ''));
		expect(fieldNames).toContain('proposalId');
		expect(fieldNames).toContain('answers');
	});

	it('TestingProposals stores bare four-digit ids (prefix is display-only)', async () => {
		const { TestingProposals } = await import('../src/collections/TestingProposals');
		const field = TestingProposals.fields.find((f) => 'name' in f && f.name === 'proposalId') as {
			validate: (value: unknown) => true | string;
		};
		expect(field.validate('0001')).toBe(true);
		// ST- prefix is presentation-only; ids are stored bare, so a prefixed id is invalid here
		expect(typeof field.validate('ST-0001')).toBe('string');
		expect(typeof field.validate('12')).toBe('string');
	});
});
