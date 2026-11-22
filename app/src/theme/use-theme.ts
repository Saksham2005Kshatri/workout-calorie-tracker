import { useColorScheme } from 'react-native';

import { darkPalette, fontSize, lightPalette, spacing } from './tokens';

export function useTheme() {
  const scheme = useColorScheme() === 'dark' ? 'dark' : 'light';
  return {
    scheme,
    colors: scheme === 'dark' ? darkPalette : lightPalette,
    spacing,
    fontSize,
  } as const;
}
