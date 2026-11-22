import { useQueryClient } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react-native';
import { Text } from 'react-native';

import { AppQueryProvider } from './query-client';

jest.mock('expo-network', () => ({
  addNetworkStateListener: jest.fn(() => ({ remove: jest.fn() })),
}));

function Probe() {
  const client = useQueryClient();
  return <Text>{client ? 'client-ready' : 'no-client'}</Text>;
}

describe('AppQueryProvider', () => {
  it('provides a query client to its children', async () => {
    await render(
      <AppQueryProvider>
        <Probe />
      </AppQueryProvider>,
    );
    expect(screen.getByText('client-ready')).toBeTruthy();
  });
});
