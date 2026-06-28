import type { CollectionConfig } from 'payload';

const PROPOSAL_ID_PATTERN = /^\d{4}$/;

// Swift Testing (ST) proposals. Stored in a separate collection/table from the
// Swift Evolution `proposals` so the 4-digit id namespaces don't collide and the
// existing SE endpoints stay byte-for-byte unchanged (backward compatible).
// The `ST-` prefix is presentation-only; ids are stored bare here.
export const TestingProposals: CollectionConfig = {
	slug: 'testing-proposals',
	admin: {
		useAsTitle: 'title',
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
					return 'proposalId must be four digits (e.g. 0001)';
				}
				return true;
			},
		},
		{
			name: 'title',
			type: 'text',
			required: true,
			maxLength: 500,
		},
		{
			name: 'authors',
			type: 'text',
			required: true,
			maxLength: 1000,
		},
		{
			name: 'content',
			type: 'textarea',
			required: true,
			maxLength: 500_000,
		},
		{
			name: 'reviewManager',
			type: 'text',
			maxLength: 200,
		},
		{
			name: 'status',
			type: 'text',
			maxLength: 500,
		},
	],
};
