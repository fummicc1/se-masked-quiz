import { withPayload } from '@payloadcms/next/withPayload'

const nextConfig = {
  // Limit build workers to 1 to prevent SQLITE_BUSY with D1 (miniflare)
  experimental: {
    cpus: 1,
  },
  serverExternalPackages: ['jose', 'pg-cloudflare', 'drizzle-kit'],
  webpack: (webpackConfig: any) => {
    webpackConfig.resolve.extensionAlias = {
      '.cjs': ['.cts', '.cjs'],
      '.js': ['.ts', '.tsx', '.js', '.jsx'],
      '.mjs': ['.mts', '.mjs'],
    }
    return webpackConfig
  },
}

export default withPayload(nextConfig, { devBundleServerPackages: false })
