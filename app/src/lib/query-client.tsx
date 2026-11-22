import {
  focusManager,
  onlineManager,
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query';
import * as Network from 'expo-network';
import { type ReactNode, useEffect, useState } from 'react';
import { AppState, type AppStateStatus } from 'react-native';

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: 2, staleTime: 30_000 },
    },
  });
}

export function AppQueryProvider({ children }: { children: ReactNode }) {
  const [client] = useState(createQueryClient);

  useEffect(() => {
    const appStateSub = AppState.addEventListener('change', (status: AppStateStatus) => {
      focusManager.setFocused(status === 'active');
    });
    const networkSub = Network.addNetworkStateListener((state) => {
      onlineManager.setOnline(state.isConnected !== false);
    });
    return () => {
      appStateSub.remove();
      networkSub.remove();
    };
  }, []);

  return <QueryClientProvider client={client}>{children}</QueryClientProvider>;
}
