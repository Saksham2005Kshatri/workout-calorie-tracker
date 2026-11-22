import { z } from 'zod';

const httpUrl = z
  .string()
  .min(1, 'is required')
  .refine((value) => {
    try {
      const { protocol } = new URL(value);
      return protocol === 'https:' || protocol === 'http:';
    } catch {
      return false;
    }
  }, 'must be an http(s) URL');

const envSchema = z.object({
  EXPO_PUBLIC_SUPABASE_URL: httpUrl,
  EXPO_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1, 'is required'),
});

export type Env = z.infer<typeof envSchema>;

/** Validates raw env values. Throws an error naming each missing or malformed variable. */
export function parseEnv(raw: Record<keyof Env, string | undefined>): Env {
  const result = envSchema.safeParse(raw);
  if (result.success) return result.data;

  const problems = result.error.issues
    .map((issue) => `${String(issue.path[0])} ${issue.message}`)
    .join('; ');
  throw new Error(`Invalid environment: ${problems}. Check app/.env against app/.env.example.`);
}
