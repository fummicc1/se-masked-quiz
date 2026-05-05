import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

const ADMIN_GATE_REALM = 'Admin Area'

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let result = 0
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return result === 0
}

export function middleware(request: NextRequest) {
  if (process.env.NODE_ENV !== 'production') {
    return NextResponse.next()
  }

  if (!request.nextUrl.pathname.startsWith('/admin')) {
    return NextResponse.next()
  }

  const user = process.env.ADMIN_GATE_USER
  const password = process.env.ADMIN_GATE_PASSWORD

  if (!user || !password) {
    return new NextResponse('Not Found', { status: 404 })
  }

  const authHeader = request.headers.get('authorization') ?? ''
  const expected = `Basic ${btoa(`${user}:${password}`)}`

  if (!timingSafeEqual(authHeader, expected)) {
    return new NextResponse('Authorization required', {
      status: 401,
      headers: {
        'WWW-Authenticate': `Basic realm="${ADMIN_GATE_REALM}", charset="UTF-8"`,
      },
    })
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/admin/:path*'],
}
