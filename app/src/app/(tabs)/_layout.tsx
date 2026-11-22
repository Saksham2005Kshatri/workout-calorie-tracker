import Ionicons from '@expo/vector-icons/Ionicons';
import { Tabs } from 'expo-router';

import { useTheme } from '@/theme/use-theme';

type IconName = React.ComponentProps<typeof Ionicons>['name'];

const TABS: { name: string; title: string; icon: IconName }[] = [
  { name: 'index', title: 'Dashboard', icon: 'home-outline' },
  { name: 'workouts', title: 'Workouts', icon: 'barbell-outline' },
  { name: 'nutrition', title: 'Nutrition', icon: 'restaurant-outline' },
  { name: 'weight', title: 'Weight', icon: 'scale-outline' },
  { name: 'profile', title: 'Profile', icon: 'person-outline' },
];

export default function TabsLayout() {
  const { colors } = useTheme();
  return (
    <Tabs
      screenOptions={{
        tabBarActiveTintColor: colors.primary,
        tabBarInactiveTintColor: colors.textMuted,
        tabBarStyle: { backgroundColor: colors.surface, borderTopColor: colors.border },
        headerStyle: { backgroundColor: colors.surface },
        headerTintColor: colors.text,
      }}
    >
      {TABS.map((tab) => (
        <Tabs.Screen
          key={tab.name}
          name={tab.name}
          options={{
            title: tab.title,
            tabBarIcon: ({ focused, size }) => (
              <Ionicons
                name={tab.icon}
                color={focused ? colors.primary : colors.textMuted}
                size={size}
              />
            ),
          }}
        />
      ))}
    </Tabs>
  );
}
