---
title: Defer Non-Critical Third-Party Libraries
impact: MEDIUM
impactDescription: loads after hydration
tags: bundle, third-party, analytics, defer
---

## Defer Non-Critical Third-Party Libraries

Analytics, logging, and error tracking don't block user interaction. Load them after hydration.

**Incorrect (blocks initial bundle):**

```tsx
import { Analytics } from '@vercel/analytics/react'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  )
}
```

**Correct (loads after hydration):**

`ssr: false` is only allowed inside Client Components, and an App Router
root layout is a Server Component - so the dynamic import lives in a small
`'use client'` wrapper that the layout renders:

```tsx
// components/lazy-analytics.tsx
'use client'

import dynamic from 'next/dynamic'

export const LazyAnalytics = dynamic(
  () => import('@vercel/analytics/react').then(m => m.Analytics),
  { ssr: false }
)
```

```tsx
// app/layout.tsx (Server Component - unchanged rendering position)
import { LazyAnalytics } from '@/components/lazy-analytics'

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        {children}
        <LazyAnalytics />
      </body>
    </html>
  )
}
```

Placing `dynamic(..., { ssr: false })` directly in a Server Component is a
Next.js build error ("`ssr: false` is not allowed with `next/dynamic` in
Server Components").
