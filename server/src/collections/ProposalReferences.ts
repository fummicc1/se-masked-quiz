import type { CollectionConfig } from 'payload';

const PROPOSAL_ID_PATTERN = /^\d{4}$/;

const validateProposalId = (value: unknown) => {
	if (typeof value !== 'string' || !PROPOSAL_ID_PATTERN.test(value)) {
		return 'proposalId must be four digits (e.g. 0001)';
	}
	return true;
};

// A single directed edge of the proposal dependency graph: `from` references `to`.
// Stored normalized (one row per edge) so both directions are index-queryable.
export const ProposalReferences: CollectionConfig = {
	slug: 'proposal-references',
	admin: {
		useAsTitle: 'fromProposalId',
	},
	access: {
		read: () => true,
		create: ({ req }) => !!req.user,
		update: ({ req }) => !!req.user,
		delete: ({ req }) => !!req.user,
	},
	fields: [
		{
			name: 'fromProposalId',
			type: 'text',
			required: true,
			index: true,
			validate: validateProposalId,
		},
		{
			name: 'toProposalId',
			type: 'text',
			required: true,
			index: true,
			validate: validateProposalId,
		},
	],
};
