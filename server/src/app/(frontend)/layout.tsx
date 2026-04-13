import React from 'react'

export const metadata = {
  title: 'SE Masked Quiz',
  description: 'Swift Evolution Masked Quiz Server',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  )
}
