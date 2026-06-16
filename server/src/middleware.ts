import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'
import { getCloudflareContext } from '@opennextjs/cloudflare'

const ADMIN_GATE_REALM = 'Admin Area'

const SECURITY_HEADERS: Record<string, string> = {
  'Strict-Transport-Security': 'max-age=63072000; includeSubDomains; preload',
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'X-Frame-Options': 'DENY',
}

const CACHEABLE_GET_PATHS = ['/api/proposals', '/api/quiz-answers']

type RateLimiterKind = 'api' | 'admin'

type RateLimiter = {
  limit: (input: { key: string }) => Promise<{ success: boolean }>
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let result = 0
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return result === 0
}

function applySecurityHeaders(response: NextResponse): NextResponse {
  for (const [key, value] of Object.entries(SECURITY_HEADERS)) {
    response.headers.set(key, value)
  }
  return response
}

function getClientIp(request: NextRequest): string {
  return (
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    'unknown'
  )
}

async function isRateLimitAllowed(request: NextRequest, kind: RateLimiterKind): Promise<boolean> {
  try {
    const ctx = getCloudflareContext()
    const env = ctx.env as unknown as { RL_API?: RateLimiter; RL_ADMIN?: RateLimiter }
    const limiter = kind === 'api' ? env.RL_API : env.RL_ADMIN
    if (!limiter) return true
    const { success } = await limiter.limit({ key: `${kind}:${getClientIp(request)}` })
    return success
  } catch {
    return true
  }
}

function tooManyRequests(): NextResponse {
  return applySecurityHeaders(
    new NextResponse('Too Many Requests', {
      status: 429,
      headers: { 'Retry-After': '10' },
    }),
  )
}

function isCacheableGet(request: NextRequest): boolean {
  if (request.method !== 'GET') return false
  const { pathname } = request.nextUrl
  return CACHEABLE_GET_PATHS.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`) || pathname.startsWith(`${prefix}?`),
  )
}

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl
  const isAdminPath = pathname.startsWith('/admin')
  const isApiPath = pathname.startsWith('/api/')

  if (isApiPath && !(await isRateLimitAllowed(request, 'api'))) {
    return tooManyRequests()
  }
  if (isAdminPath && !(await isRateLimitAllowed(request, 'admin'))) {
    return tooManyRequests()
  }

  if (process.env.NODE_ENV === 'production' && isAdminPath) {
    const user = process.env.ADMIN_GATE_USER
    const password = process.env.ADMIN_GATE_PASSWORD

    if (!user || !password) {
      return applySecurityHeaders(new NextResponse('Not Found', { status: 404 }))
    }

    const authHeader = request.headers.get('authorization') ?? ''
    const expected = `Basic ${btoa(`${user}:${password}`)}`

    if (!timingSafeEqual(authHeader, expected)) {
      return applySecurityHeaders(
        new NextResponse('Authorization required', {
          status: 401,
          headers: {
            'WWW-Authenticate': `Basic realm="${ADMIN_GATE_REALM}", charset="UTF-8"`,
          },
        }),
      )
    }
  }

  const response = NextResponse.next()
  applySecurityHeaders(response)

  if (isCacheableGet(request)) {
    response.headers.set('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=60')
  }

  return response
}

export const config = {
  matcher: ['/admin/:path*', '/api/:path*'],
}
