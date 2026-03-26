import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  devToolbar: { enabled: true },
  vite: {
    plugins: [tailwindcss()],
  },
});
