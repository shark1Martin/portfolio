// GET endpoints for the shared clipboard, served by the clip_* functions in
// supabase/clipboard_v2_setup.sql. The anon key already ships in the page
// bundle, so putting it in these URLs exposes nothing new; RLS decides what
// it can do.

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY as string | undefined;

// How many texts and how many screenshots the page keeps.
export const KEEP_PER_KIND = 20;

export type Endpoint = {
  label: string;
  url: string;
  notes: string[];
  examples: string[];
};

function rpc(name: string) {
  return `${supabaseUrl}/rest/v1/rpc/${name}?apikey=${anonKey}`;
}

export const clipboardEndpoints: Endpoint[] =
  supabaseUrl && anonKey
    ? [
        {
          label: 'Texts',
          url: rpc('clip_text'),
          notes: [
            'Raw text/plain. Returns the newest text.',
            `&n=2 is the one before it, &n=3 the one before that, up to &n=${KEEP_PER_KIND}.`,
            '&id=<id> gets a specific one. 404 when there is no such text.',
          ],
          examples: [
            `curl -s "${rpc('clip_text')}"`,
            `Last 3 texts: for i in 1 2 3; do curl -s "${rpc('clip_text')}&n=$i" -o text-$i.txt; done`,
          ],
        },
        {
          label: 'Screenshots',
          url: rpc('clip_image'),
          notes: [
            'Redirects (302) to the newest screenshot, so follow redirects (curl -L).',
            `&n=2 is the one before it, &n=3 the one before that, up to &n=${KEEP_PER_KIND}.`,
            '&id=<id> gets a specific one. 404 when there is no such screenshot.',
          ],
          examples: [
            `curl -sL "${rpc('clip_image')}" -o screenshot.png`,
            `Last 3 screenshots: for i in 1 2 3; do curl -sL "${rpc('clip_image')}&n=$i" -o screenshot-$i.png; done`,
          ],
        },
        {
          label: 'Uploaded file',
          url: rpc('clip_file'),
          notes: [
            'Redirects (302) to the file. There is one file slot.',
            'Its original name is file.name in the JSON below.',
          ],
          examples: [`curl -sL "${rpc('clip_file')}" -o <name>`],
        },
        {
          label: 'Everything (JSON)',
          url: rpc('clip_state'),
          notes: [
            `The newest text in full, the newest screenshot, the file, and the last ${KEEP_PER_KIND} texts (200-char previews) and screenshots, newest first, with ids and timestamps.`,
            `URLs inside are relative to ${supabaseUrl}.`,
          ],
          examples: [`curl -s "${rpc('clip_state')}"`],
        },
      ]
    : [];
