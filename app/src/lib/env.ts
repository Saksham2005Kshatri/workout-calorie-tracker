import { parseEnv } from './env-schema';

// Expo only inlines static `process.env.EXPO_PUBLIC_*` references, so each one is read by name.
export const env = parseEnv({
  EXPO_PUBLIC_SUPABASE_URL: process.env.EXPO_PUBLIC_SUPABASE_URL,
  EXPO_PUBLIC_SUPABASE_ANON_KEY: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
});
