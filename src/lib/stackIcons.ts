/**
 * Maps stack labels from content to Simple Icons slugs.
 * @see https://simpleicons.org — CDN: https://cdn.simpleicons.org/{slug}
 */
const ALIASES: Record<string, string> = {
  // Languages
  typescript: 'typescript',
  ts: 'typescript',
  javascript: 'javascript',
  js: 'javascript',
  python: 'python',
  py: 'python',
  java: 'java',
  rust: 'rust',
  go: 'go',
  golang: 'go',
  ruby: 'ruby',
  php: 'php',
  swift: 'swift',
  kotlin: 'kotlin',
  c: 'c',
  'c++': 'cplusplus',
  cpp: 'cplusplus',
  'c#': 'csharp',
  csharp: 'csharp',
  dart: 'dart',

  // Web / UI
  html: 'html5',
  html5: 'html5',
  css: 'css3',
  css3: 'css3',
  sass: 'sass',
  scss: 'sass',
  'tailwind css': 'tailwindcss',
  tailwindcss: 'tailwindcss',
  tailwind: 'tailwindcss',
  react: 'react',
  'next.js': 'nextdotjs',
  nextjs: 'nextdotjs',
  'node.js': 'nodedotjs',
  node: 'nodedotjs',
  express: 'express',
  vue: 'vuedotjs',
  'vue.js': 'vuedotjs',
  angular: 'angular',
  svelte: 'svelte',
  astro: 'astro',
  remix: 'remix',

  // Data / backend
  fastapi: 'fastapi',
  django: 'django',
  flask: 'flask',
  postgresql: 'postgresql',
  postgres: 'postgresql',
  mysql: 'mysql',
  mongodb: 'mongodb',
  redis: 'redis',
  sqlite: 'sqlite',
  prisma: 'prisma',

  // Cloud / DevOps
  docker: 'docker',
  kubernetes: 'kubernetes',
  aws: 'amazonaws',
  azure: 'microsoftazure',
  gcp: 'googlecloud',
  firebase: 'firebase',
  vercel: 'vercel',
  nginx: 'nginx',

  // Tools
  git: 'git',
  github: 'github',
  graphql: 'graphql',
  figma: 'figma',
};

/** Slugs that are mostly black; use white on dark backgrounds. */
const LIGHT_ON_DARK = new Set(['github', 'nextdotjs', 'vercel']);

function normalizeKey(label: string): string {
  return label.trim().toLowerCase();
}

export function getSimpleIconSlug(tech: string): string | null {
  const key = normalizeKey(tech);
  if (ALIASES[key]) return ALIASES[key];
  // e.g. "SomeFramework" → "someframework" if it matches a slug pattern
  const compact = key.replace(/[^a-z0-9]/g, '');
  if (compact && ALIASES[compact]) return ALIASES[compact];
  return null;
}

export function getSimpleIconSrc(slug: string): string {
  const base = `https://cdn.simpleicons.org/${slug}`;
  if (LIGHT_ON_DARK.has(slug)) return `${base}/ffffff`;
  return base;
}
