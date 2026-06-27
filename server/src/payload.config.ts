import fs from 'fs';
import path from 'path';
import { sqliteD1Adapter } from '@payloadcms/db-d1-sqlite';
import { lexicalEditor } from '@payloadcms/richtext-lexical';
import { buildConfig } from 'payload';
import { fileURLToPath } from 'url';
import type { CloudflareContext } from '@opennextjs/cloudflare';
import { getCloudflareContext } from '@opennextjs/cloudflare';
import type { GetPlatformProxyOptions } from 'wrangler';

import { Proposals } from './collections/Proposals';
import { ProposalReferences } from './collections/ProposalReferences';
import { QuizAnswers } from './collections/QuizAnswers';
import { Users } from './collections/Users';

const filename = fileURLToPath(import.meta.url);
const dirname = path.dirname(filename);
const realpath = (value: string) => {
	const resolved = fs.existsSync(value) ? fs.realpathSync(value) : undefined;
	return resolved;
};

const isCLI = process.argv.some((value) => realpath(value)?.endsWith(path.join('payload', 'bin.js')));
const isProduction = process.env.NODE_ENV === 'production';

// Custom JSON logger for Cloudflare Workers (pino-pretty is not supported)
const createLog = (level: string, fn: typeof console.log) => (objOrMsg: object | string, msg?: string) => {
	if (typeof objOrMsg === 'string') {
		fn(JSON.stringify({ level, msg: objOrMsg }));
	} else {
		fn(JSON.stringify({ level, ...objOrMsg, msg: msg ?? (objOrMsg as { msg?: string }).msg }));
	}
};

const cloudflareLogger = {
	level: process.env.PAYLOAD_LOG_LEVEL || 'info',
	trace: createLog('trace', console.debug),
	debug: createLog('debug', console.debug),
	info: createLog('info', console.log),
	warn: createLog('warn', console.warn),
	error: createLog('error', console.error),
	fatal: createLog('fatal', console.error),
	silent: () => {},
} as any;

function getCloudflareContextFromWrangler(): Promise<CloudflareContext> {
	return import(/* webpackIgnore: true */ `${'__wrangler'.replaceAll('_', '')}`).then(({ getPlatformProxy }) =>
		getPlatformProxy({
			environment: process.env.CLOUDFLARE_ENV,
			remoteBindings: isProduction,
		} satisfies GetPlatformProxyOptions),
	);
}

const cloudflare = isCLI || !isProduction ? await getCloudflareContextFromWrangler() : await getCloudflareContext({ async: true });

// Cloudflare Workers Builds does not expose runtime secrets during `next build`,
// so the secret is only enforced at runtime. The placeholder is never used in
// production: at runtime the real secret is required or startup fails below.
const isBuildPhase = process.env.NEXT_PHASE === 'phase-production-build';

if (!isBuildPhase && !process.env.PAYLOAD_SECRET) {
	throw new Error('PAYLOAD_SECRET environment variable is required');
}

export default buildConfig({
	secret: process.env.PAYLOAD_SECRET || 'build-time-placeholder-never-used-at-runtime',
	db: sqliteD1Adapter({
		binding: cloudflare.env.DB,
	}),
	editor: lexicalEditor(),
	collections: [Users, Proposals, QuizAnswers, ProposalReferences],
	logger: isProduction ? cloudflareLogger : undefined,
	// iOS app is the only client; browsers must not be able to call this API.
	cors: [],
	csrf: [],
	graphQL: {
		disable: true,
	},
	admin: {
		user: Users.slug,
		importMap: {
			baseDir: path.resolve(dirname),
		},
	},
	typescript: {
		outputFile: path.resolve(dirname, 'payload-types.ts'),
	},
});
