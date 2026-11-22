import { StyleSheet, Text, View } from 'react-native';

import { useTheme } from '@/theme/use-theme';

type Props = {
  title: string;
  description: string;
};

export function PlaceholderScreen({ title, description }: Props) {
  const { colors, spacing, fontSize } = useTheme();
  return (
    <View
      style={[styles.container, { backgroundColor: colors.background, padding: spacing.lg }]}
      testID="placeholder-screen"
    >
      <Text style={{ color: colors.text, fontSize: fontSize.title, fontWeight: '600' }}>
        {title}
      </Text>
      <Text
        style={{
          color: colors.textMuted,
          fontSize: fontSize.body,
          marginTop: spacing.sm,
          textAlign: 'center',
        }}
      >
        {description}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
