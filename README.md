# Portfolio

Personal portfolio site — Porsche-inspired dark design.

## Stack

- [Astro](https://astro.build) — static site framework
- [Tailwind CSS](https://tailwindcss.com) — utility-first styling
- [Inter](https://fonts.google.com/specimen/Inter) — heading font
- [JetBrains Mono](https://fonts.google.com/specimen/JetBrains+Mono) — monospace labels

## Getting Started

```bash
npm install
npm run dev
```

Open [http://localhost:4321](http://localhost:4321).

## Customizing Content

All content lives directly in the component files — no CMS, no config files to hunt down.

| Section    | File                               |
| ---------- | ---------------------------------- |
| Hero       | `src/components/Hero.astro`        |
| Projects   | `src/components/Projects.astro`    |
| Experience | `src/components/Experience.astro`  |
| Club Work  | `src/components/ClubWork.astro`    |
| Contact    | `src/components/Contact.astro`     |
| Nav        | `src/components/Nav.astro`         |

Each file has a clearly marked data block at the top — just replace the placeholder strings.

## Design Tokens

| Token          | Value     | Usage                        |
| -------------- | --------- | ---------------------------- |
| Background     | `#0f0f0f` | Page background              |
| Surface        | `#1a1a1a` | Cards, panels                |
| Guards Red     | `#B00000` | Accents, CTAs, active states |
| Text Primary   | `#f5f5f5` | Headings, body               |
| Text Secondary | `#999999` | Subtext, descriptions        |
| Text Muted     | `#555555` | Labels, metadata             |
| Border         | `#2a2a2a` | Dividers, card borders       |

## Build

```bash
npm run build    # outputs to dist/
npm run preview  # preview the production build
```

## `/secret` — shared clipboard

A public page where anyone with the link can paste text/code/images into a
single shared slot that anyone else can see, copy, delete, or overwrite.
Backed by [Supabase](https://supabase.com) (Postgres + Storage), called
directly from the browser — no server needed, so it still works on static
GitHub Pages hosting.

**One-time setup:**

1. Create a free Supabase project at [supabase.com](https://supabase.com).
2. In the SQL Editor, run `supabase/secret_paste_setup.sql` — creates the
   table, RLS policies, and the `secret-uploads` storage bucket.
3. From Project Settings → API, copy the Project URL and the `anon` `public`
   key into `.env` (see `.env.example`) for local dev.
4. Add the same two values as repository secrets (Settings → Secrets and
   variables → Actions) named `PUBLIC_SUPABASE_URL` and
   `PUBLIC_SUPABASE_ANON_KEY` — the deploy workflow bakes them into the
   static build, same as `PUBLIC_GA_MEASUREMENT_ID`.
5. The `supabase-keepalive.yml` workflow pings the database every 3 days so
   the free-tier project never auto-pauses from inactivity. No setup needed
   beyond the secrets above.

**Guardrails already in place:** 50,000-character cap on text, 5MB cap on
images, image-only MIME allowlist — all enforced server-side (DB constraint
+ storage bucket config), not just in the page's JS. The anon key can only
read/update the single existing row and upload to that one bucket; it can't
create new rows or touch anything else in the project.
