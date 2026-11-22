import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

import '@/lib/env'; // validates environment variables at startup
import { AppQueryProvider } from '@/lib/query-client';

export default function RootLayout() {
  return (
    <AppQueryProvider>
      <StatusBar style="auto" />
      <Stack screenOptions={{ headerShown: false }} />
    </AppQueryProvider>
  );
}
