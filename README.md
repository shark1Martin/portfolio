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
