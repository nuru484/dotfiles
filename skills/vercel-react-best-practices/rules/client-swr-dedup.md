---
title: Use SWR for Automatic Deduplication
impact: MEDIUM-HIGH
impactDescription: automatic deduplication
tags: client, swr, deduplication, data-fetching
---

## Use SWR for Automatic Deduplication

> **House override:** in this user's stack the client data layer is RTK Query
> (see `frontend-conventions`), which already provides the dedup, caching,
> and revalidation this rule wants. Apply the PRINCIPLE (never raw
> fetch/useEffect per component) through RTK Query endpoints; do not install
> SWR alongside it. The SWR code below applies only to projects that don't
> use RTK Query.

SWR enables request deduplication, caching, and revalidation across component instances.

**Incorrect (no deduplication, each instance fetches):**

```tsx
function UserList() {
  const [users, setUsers] = useState([])
  useEffect(() => {
    fetch('/api/users')
      .then(r => r.json())
      .then(setUsers)
  }, [])
}
```

**Correct (multiple instances share one request):**

```tsx
import useSWR from 'swr'

function UserList() {
  const { data: users } = useSWR('/api/users', fetcher)
}
```

**For immutable data:**

```tsx
import useSWRImmutable from 'swr/immutable'

function StaticContent() {
  const { data } = useSWRImmutable('/api/config', fetcher)
}
```

**For mutations:**

```tsx
import useSWRMutation from 'swr/mutation'

function UpdateButton() {
  const { trigger } = useSWRMutation('/api/user', updateUser)
  return <button onClick={() => trigger()}>Update</button>
}
```

Reference: [https://swr.vercel.app](https://swr.vercel.app)
