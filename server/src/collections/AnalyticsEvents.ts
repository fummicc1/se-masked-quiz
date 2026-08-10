import type { CollectionConfig } from 'payload';

// Anonymous usage events posted by the iOS app (no auth). Abuse is bounded by
// the middleware rate limit (60 req/10s per IP) plus the strict validation below.
const EVENT_NAMES = new Set([
	'app_open',
	'quiz_started',
	'quiz_answered',
	'daily_challenge_completed',
	'streak_incremented',
	'notification_permission',
	'notification_opened',
	'reminder_time_set',
	'stats_screen_viewed',
]);

// iOS UUID().uuidString is uppercase; accept both cases.
const ANON_ID_PATTERN = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const MAX_PARAM_ENTRIES = 8;
const MAX_PARAM_KEY_LENGTH = 40;
const MAX_PARAM_VALUE_LENGTH = 200;
const MAX_APP_VERSION_LENGTH = 32;

const isParamsShape = (value: unknown): value is Record<string, string> => {
	if (value === null || typeof value !== 'object' || Array.isArray(value)) return false;
	const entries = Object.entries(value as Record<string, unknown>);
	if (entries.length > MAX_PARAM_ENTRIES) return false;
	return entries.every(
		([key, entry]) => key.length <= MAX_PARAM_KEY_LENGTH && typeof entry === 'string' && entry.length <= MAX_PARAM_VALUE_LENGTH,
	);
};

export const AnalyticsEvents: CollectionConfig = {
	slug: 'analytics-events',
	admin: {
		useAsTitle: 'name',
		defaultColumns: ['name', 'anonId', 'createdAt'],
	},
	access: {
		create: () => true,
		read: ({ req }) => !!req.user,
		update: () => false,
		delete: () => false,
	},
	fields: [
		{
			name: 'name',
			type: 'text',
			required: true,
			index: true,
			validate: (value: unknown) => {
				if (typeof value !== 'string' || !EVENT_NAMES.has(value)) {
					return 'name must be a known analytics event name';
				}
				return true;
			},
		},
		{
			name: 'anonId',
			type: 'text',
			required: true,
			index: true,
			validate: (value: unknown) => {
				if (typeof value !== 'string' || !ANON_ID_PATTERN.test(value)) {
					return 'anonId must be a UUID string';
				}
				return true;
			},
		},
		{
			name: 'params',
			type: 'json',
			required: false,
			validate: (value: unknown) => {
				if (value === null || value === undefined) return true;
				if (!isParamsShape(value)) {
					return `params must be an object of at most ${MAX_PARAM_ENTRIES} short string entries`;
				}
				return true;
			},
		},
		{
			name: 'appVersion',
			type: 'text',
			required: false,
			validate: (value: unknown) => {
				if (value === null || value === undefined) return true;
				if (typeof value !== 'string' || value.length > MAX_APP_VERSION_LENGTH) {
					return `appVersion must be a string of at most ${MAX_APP_VERSION_LENGTH} characters`;
				}
				return true;
			},
		},
	],
};
