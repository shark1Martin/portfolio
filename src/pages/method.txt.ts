import type { APIRoute } from 'astro';
import { clipboardEndpoints } from '../lib/clipboardApi';

// Plain-text index of the shared clipboard's GET endpoints, for scripts and
// agents that would rather not parse the page's HTML.
export const GET: APIRoute = () => {
  const lines = [
    'Shared clipboard: machine access',
    '',
    'Every endpoint is a plain HTTP GET. No headers needed.',
    'Texts and screenshots are kept separately, newest first. n=1 is the newest.',
    'Screenshots download as image files: save them, then open them to look at them.',
    '',
  ];

  if (clipboardEndpoints.length === 0) {
    lines.push('Not configured.');
  }

  for (const endpoint of clipboardEndpoints) {
    lines.push(
      endpoint.label,
      `  GET ${endpoint.url}`,
      ...endpoint.notes.map((note) => `  ${note}`),
      ...endpoint.examples.map((example) => `  e.g. ${example}`),
      ''
    );
  }

  return new Response(lines.join('\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
