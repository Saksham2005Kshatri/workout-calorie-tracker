import { renderHook } from '@testing-library/react-native';
import * as ReactNative from 'react-native';

import { darkPalette, lightPalette } from './tokens';
import { useTheme } from './use-theme';

describe('useTheme', () => {
  afterEach(() => jest.restoreAllMocks());

  it('returns the dark palette when the system scheme is dark', async () => {
    jest.spyOn(ReactNative, 'useColorScheme').mockReturnValue('dark');
    const { result } = await renderHook(() => useTheme());
    expect(result.current.scheme).toBe('dark');
    expect(result.current.colors).toBe(darkPalette);
  });

  it('returns the light palette when the system scheme is light', async () => {
    jest.spyOn(ReactNative, 'useColorScheme').mockReturnValue('light');
    const { result } = await renderHook(() => useTheme());
    expect(result.current.colors).toBe(lightPalette);
  });

  it('falls back to light when the scheme is unknown', async () => {
    jest.spyOn(ReactNative, 'useColorScheme').mockReturnValue(null);
    const { result } = await renderHook(() => useTheme());
    expect(result.current.scheme).toBe('light');
  });
});
