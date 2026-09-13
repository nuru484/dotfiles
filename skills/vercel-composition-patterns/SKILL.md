---
name: vercel-composition-patterns
description: "Design or refactor React compound components, shared UI state, or component APIs with proliferating behavior variants. Do not introduce context or composition layers for simple independent components."

license: MIT
metadata:
  author: vercel
  version: '1.0.0'
---

# React Composition Patterns

Composition patterns for building flexible, maintainable React components. Avoid
boolean prop proliferation by using compound components, lifting state, and
composing internals. These patterns make codebases easier for both humans and AI
agents to work with as they scale.

## House addenda (apply whenever using these patterns)

- **Client boundary**: context providers/consumers and interactive state belong
  in Client Components. Server Components may import and render those components
  and pass server-rendered children. Do not import server-only modules into the
  client graph. React.use itself is not exclusively client-side.
- **Null-guard hook**: contexts are created with `null` defaults, so consumers
  use a guard hook, never bare `use(SomeContext)` destructuring:
  ```tsx
  export function useComposer() {
    const ctx = use(ComposerContext)
    if (ctx === null) throw new Error("useComposer must be used within <Composer.Provider>")
    return ctx
  }
  ```
  Bare destructuring fails strict TypeScript and crashes cryptically when a
  part renders outside its provider.
- **Context performance**: split unrelated state or stabilize provider values when
  unnecessary consumer renders are a demonstrated issue. Do not add memoization
  mechanically to cheap components.
- **Boolean props are fine in moderation**: `disabled`, `isLoading`, `open`
  are idiomatic. Reach for composition when TWO OR MORE behavior-switching
  booleans gate different subtrees of the same component, not for every flag.
- **Forms are not composer state**: form field state/validation belongs to
  react-hook-form (`frontend-conventions`); these providers coordinate
  non-form UI state, or wrap RHF's own `FormProvider`.
- **React version gate**: `use()`, `<Context value>`-as-provider, and
  ref-as-prop require React 19. On React 18, substitute `useContext`,
  `<Context.Provider value>`, and `forwardRef` throughout, including in
  sections 1-3 whose examples use React 19 syntax.

## When to Apply

Reference these guidelines when:

- Refactoring components with many boolean props
- Building reusable component libraries
- Designing flexible component APIs
- Reviewing component architecture
- Working with compound components or context providers

## Rule Categories by Priority

| Priority | Category                | Impact | Prefix          |
| -------- | ----------------------- | ------ | --------------- |
| 1        | Component Architecture  | HIGH   | `architecture-` |
| 2        | State Management        | MEDIUM | `state-`        |
| 3        | Implementation Patterns | MEDIUM | `patterns-`     |
| 4        | React 19 APIs           | MEDIUM | `react19-`      |

## Quick Reference

### 1. Component Architecture (HIGH)

- `architecture-avoid-boolean-props` - Don't add boolean props to customize
  behavior; use composition
- `architecture-compound-components` - Structure complex components with shared
  context

### 2. State Management (MEDIUM)

- `state-decouple-implementation` - Provider is the only place that knows how
  state is managed
- `state-context-interface` - Define generic interface with state, actions, meta
  for dependency injection
- `state-lift-state` - Move state into provider components for sibling access

### 3. Implementation Patterns (MEDIUM)

- `patterns-explicit-variants` - Create explicit variant components instead of
  boolean modes
- `patterns-children-over-render-props` - Use children for composition instead
  of renderX props

### 4. React 19 APIs (MEDIUM)

> **React 19+ only.** Skip this section if using React 18 or earlier.

- `react19-no-forwardref` - Don't use `forwardRef`; use `use()` instead of `useContext()`

## How to Use

Read individual rule files for detailed explanations and code examples:

```
rules/architecture-avoid-boolean-props.md
rules/state-context-interface.md
```

Each rule file contains:

- Brief explanation of why it matters
- Incorrect code example with explanation
- Correct code example with explanation

Read the individual rule files above; there is no compiled aggregate (the
upstream AGENTS.md/README were removed here as duplicative build artifacts).
Load only the rules relevant to the component at hand.
