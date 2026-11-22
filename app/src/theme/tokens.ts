export type Palette = {
  background: string;
  surface: string;
  text: string;
  textMuted: string;
  border: string;
  primary: string;
  onPrimary: string;
  danger: string;
};

export const lightPalette: Palette = {
  background: '#F5F7F8',
  surface: '#FFFFFF',
  text: '#12181B',
  textMuted: '#5A6770',
  border: '#D5DCE0',
  primary: '#0B7A66',
  onPrimary: '#FFFFFF',
  danger: '#B3261E',
};

export const darkPalette: Palette = {
  background: '#0E1214',
  surface: '#171D20',
  text: '#E8EDEF',
  textMuted: '#93A1A9',
  border: '#2B3438',
  primary: '#3CC4A8',
  onPrimary: '#06201A',
  danger: '#F2B8B5',
};

export const spacing = { xs: 4, sm: 8, md: 16, lg: 24, xl: 32 } as const;

export const fontSize = { caption: 13, body: 16, title: 22, display: 30 } as const;
