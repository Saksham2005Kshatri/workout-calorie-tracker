import { parseEnv } from './env-schema';

const valid = {
  EXPO_PUBLIC_SUPABASE_URL: 'https://abc.supabase.co',
  EXPO_PUBLIC_SUPABASE_ANON_KEY: 'key-123',
};

describe('parseEnv', () => {
  it('returns a typed config for valid values', () => {
    expect(parseEnv(valid)).toEqual(valid);
  });

  it('accepts a local http URL for local Supabase development', () => {
    const env = parseEnv({ ...valid, EXPO_PUBLIC_SUPABASE_URL: 'http://127.0.0.1:54321' });
    expect(env.EXPO_PUBLIC_SUPABASE_URL).toBe('http://127.0.0.1:54321');
  });

  it('names the variable when the URL is missing', () => {
    expect(() => parseEnv({ ...valid, EXPO_PUBLIC_SUPABASE_URL: undefined })).toThrow(
      /EXPO_PUBLIC_SUPABASE_URL/,
    );
  });

  it('rejects a URL that is not http(s)', () => {
    expect(() => parseEnv({ ...valid, EXPO_PUBLIC_SUPABASE_URL: 'ftp://abc.supabase.co' })).toThrow(
      /EXPO_PUBLIC_SUPABASE_URL/,
    );
    expect(() => parseEnv({ ...valid, EXPO_PUBLIC_SUPABASE_URL: 'not a url' })).toThrow(
      /EXPO_PUBLIC_SUPABASE_URL/,
    );
  });

  it('rejects an empty key', () => {
    expect(() => parseEnv({ ...valid, EXPO_PUBLIC_SUPABASE_ANON_KEY: '' })).toThrow(
      /EXPO_PUBLIC_SUPABASE_ANON_KEY/,
    );
  });

  it('reports every bad variable in one error', () => {
    expect(() =>
      parseEnv({ EXPO_PUBLIC_SUPABASE_URL: undefined, EXPO_PUBLIC_SUPABASE_ANON_KEY: undefined }),
    ).toThrow(/EXPO_PUBLIC_SUPABASE_URL.*EXPO_PUBLIC_SUPABASE_ANON_KEY/s);
  });
});
