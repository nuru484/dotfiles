# Scroll-Driven Patterns: Canonical Skeletons and Hard Bans

For pinned card stacks and horizontal scroll-hijacks on marketing pages.
Adapted from Leonxlnx/taste-skill (MIT). Motion decision rules (whether to
animate at all, easing, duration) come from `emil-design-eng`/`animate`;
this file exists because improvised ScrollTrigger configs are the most
common way these patterns break.

## Hard bans (any of these fails review)

- **`window.addEventListener("scroll", ...)`** - runs unbatched on every
  frame. Use Motion's `useScroll()`, GSAP ScrollTrigger, IntersectionObserver,
  or CSS scroll-driven animations (`animation-timeline: view()`).
- **`window.scrollY` into React state** - re-renders the tree per frame.
- **`requestAnimationFrame` loops that set React state** - use
  `useMotionValue` + `useTransform`.
- **`useState` for any continuous input-driven value** (mouse position,
  scroll progress, drag) - motion values only; state re-renders collapse on
  mobile.
- **Two animation DRIVERS in one component tree** (GSAP or Three.js driving
  frames alongside Motion animations) - they fight over frames. One driver
  per tree, isolated in its own `"use client"` leaf with a cleanup function.
  Reading a Motion utility hook like `useReducedMotion` inside a GSAP
  component is NOT a second driver and is fine (the skeletons below do it).

## Sticky-stack (cards pin and stack on scroll)

The two classic failures: triggers firing mid-viewport instead of pinning at
the top, and missing cleanup. `start: "top top"` and `ctx.revert()` are the
fixes; every card except the last pins, and each card's shrink is driven by
the NEXT card's approach.

```tsx
"use client";
import { useRef, useEffect } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useReducedMotion } from "motion/react";

gsap.registerPlugin(ScrollTrigger);

export function StickyStack({ cards }: { cards: React.ReactNode[] }) {
  const ref = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();

  useEffect(() => {
    if (reduce || !ref.current) return;
    const ctx = gsap.context(() => {
      const els = gsap.utils.toArray<HTMLElement>(".stack-card");
      els.forEach((card, i) => {
        if (i === els.length - 1) return;
        ScrollTrigger.create({
          trigger: card,
          start: "top top", // pin at viewport top - never "top center"
          endTrigger: els[els.length - 1],
          end: "top top",
          pin: true,
          pinSpacing: false,
        });
        gsap.to(card, {
          scale: 0.92,
          opacity: 0.55,
          ease: "none",
          scrollTrigger: { trigger: els[i + 1], start: "top bottom", end: "top top", scrub: true },
        });
      });
    }, ref);
    return () => ctx.revert();
  }, [reduce]);

  return (
    <div ref={ref} className="relative">
      {cards.map((card, i) => (
        <div key={i} className="stack-card sticky top-0 min-h-[100dvh] flex items-center justify-center">
          {card}
        </div>
      ))}
    </div>
  );
}
```

## Horizontal pan (vertical scroll drives horizontal travel)

Classic failure: the animation starts before the section pins, so the user
sees half a slide. Pin the wrapper at `top top`, scrub the inner track, and
make the scroll distance equal the horizontal travel.

```tsx
"use client";
import { useRef, useEffect } from "react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { useReducedMotion } from "motion/react";

gsap.registerPlugin(ScrollTrigger);

export function HorizontalPan({ children }: { children: React.ReactNode }) {
  const wrap = useRef<HTMLDivElement>(null);
  const track = useRef<HTMLDivElement>(null);
  const reduce = useReducedMotion();

  useEffect(() => {
    if (reduce || !wrap.current || !track.current) return;
    const ctx = gsap.context(() => {
      const distance = track.current!.scrollWidth - window.innerWidth;
      gsap.to(track.current, {
        x: -distance,
        ease: "none",
        scrollTrigger: {
          trigger: wrap.current,
          start: "top top",
          end: () => `+=${distance}`,
          pin: true,
          scrub: 1,
          invalidateOnRefresh: true,
        },
      });
    }, wrap);
    return () => ctx.revert();
  }, [reduce]);

  return (
    <section ref={wrap} className="relative overflow-hidden">
      <div ref={track} className="flex h-[100dvh] items-center">{children}</div>
    </section>
  );
}
```

## Scroll-reveal stagger (the lighter default)

For "items appear as they enter the viewport" with no pinning, skip GSAP
entirely: Motion's `whileInView` is lighter and needs no plugin. The motion
INGREDIENTS here are the `animate` skill's: its strong ease-out token
(`cubic-bezier(0.23, 1, 0.32, 1)`), stagger delays inside its 30-80ms band,
and full transform strings (the `y` shorthand is not hardware-accelerated
and drops frames while a marketing page is loading images). For other
reveal/stagger variants, start from `animate`'s RECIPES.md - this file's
own property is the GSAP pin/scrub skeletons above.

```tsx
"use client";
import { motion, useReducedMotion } from "motion/react";

export function RevealStagger({ items }: { items: string[] }) {
  const reduce = useReducedMotion();
  return (
    <ul className="grid gap-6">
      {items.map((item, i) => (
        <motion.li
          key={item}
          // reduced motion keeps an opacity-only fade (gentler, not zero)
          initial={{ opacity: 0, transform: reduce ? "none" : "translateY(24px)" }}
          whileInView={{ opacity: 1, transform: "translateY(0px)" }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.6, delay: i * 0.06, ease: [0.23, 1, 0.32, 1] }}
        >
          {item}
        </motion.li>
      ))}
    </ul>
  );
}
```

Use this for feature lists, testimonial grids, and logo walls. Reserve GSAP
for genuine pin/scrub work. Under reduced motion the pin/scrub patterns
collapse to static (pure positional motion has no gentle variant); the
stagger keeps its opacity-only fade per the emil-design-eng rule that
reduced motion means gentler, not zero. Grain/noise overlays go on fixed
`pointer-events-none` elements only, never scrolling containers.
