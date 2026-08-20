---

title: Extract Default Non-primitive Parameter Value from Memoized Component to Constant
impact: MEDIUM
impactDescription: restores memoization by using a constant for default value
tags: rerender, memo, optimization

---

## Extract Default Non-primitive Parameter Value from Memoized Component to Constant

When a memoized component declares a non-primitive default (array, function, object) for an optional prop, the default expression is re-evaluated on every render the component performs, producing a new instance each time. Precisely: `memo()` itself still works (it compares the incoming props object, where the omitted prop is `undefined` on every render), but the fresh default value breaks everything DOWNSTREAM of it - hook dependency arrays that include it, memoized children that receive it, and effects keyed on it re-run/re-render on every parent-triggered render.

To address this, extract the default value into a module-level constant so its identity is stable.

**Incorrect (`onClick` has different values on every rerender):**

```tsx
const UserAvatar = memo(function UserAvatar({ onClick = () => {} }: { onClick?: () => void }) {
  // ...
})

// Used without optional onClick
<UserAvatar />
```

**Correct (stable default value):**

```tsx
const NOOP = () => {};

const UserAvatar = memo(function UserAvatar({ onClick = NOOP }: { onClick?: () => void }) {
  // ...
})

// Used without optional onClick
<UserAvatar />
```
