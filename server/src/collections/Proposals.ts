import type { CollectionConfig } from 'payload'

const PROPOSAL_ID_PATTERN = /^SE-\d{4}$/

export const Proposals: CollectionConfig = {
  slug: 'proposals',
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
          return 'proposalId must match SE-NNNN (e.g. SE-0001)'
        }
        return true
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
      maxLength: 100,
    },
  ],
}
