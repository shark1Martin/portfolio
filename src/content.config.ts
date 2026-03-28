import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const projects = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/projects' }),
  schema: z.object({
    name: z.string(),
    description: z.string(),
    stack: z.array(z.string()),
    status: z.enum(['Shipped', 'In Progress', 'Concept']),
    github: z.string().url().optional(),
    demo: z.string().url().optional(),
    year: z.string().optional(),
    featured: z.boolean().default(false),
    visible: z.boolean().default(true),
  }),
});

export const collections = { projects };
