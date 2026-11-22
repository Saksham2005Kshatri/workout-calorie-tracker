import { render, screen } from '@testing-library/react-native';
import { renderRouter } from 'expo-router/testing-library';
import * as ReactNative from 'react-native';

import { PlaceholderScreen } from '@/components/placeholder-screen';
import { darkPalette } from '@/theme/tokens';
import TabsLayout from './_layout';
import Dashboard from './index';
import Nutrition from './nutrition';
import Profile from './profile';
import Weight from './weight';
import Workouts from './workouts';

const routes = {
  '(tabs)/_layout': TabsLayout,
  '(tabs)/index': Dashboard,
  '(tabs)/workouts': Workouts,
  '(tabs)/nutrition': Nutrition,
  '(tabs)/weight': Weight,
  '(tabs)/profile': Profile,
};

describe('tab shell', () => {
  afterEach(() => jest.restoreAllMocks());

  it('renders the five tabs in order', async () => {
    await renderRouter(routes, { initialUrl: '/' });
    const titles = ['Dashboard', 'Workouts', 'Nutrition', 'Weight', 'Profile'];
    for (const title of titles) {
      expect(screen.getAllByText(title).length).toBeGreaterThan(0);
    }
  });

  it('opens on the Dashboard placeholder', async () => {
    await renderRouter(routes, { initialUrl: '/' });
    expect(screen.getByText(/Phases 4 to 9/)).toBeTruthy();
  });

  it('navigates to each placeholder screen', async () => {
    await renderRouter(routes, { initialUrl: '/weight' });
    expect(screen.getByText(/Weight log and progress graph/)).toBeTruthy();
  });

  it('uses the dark palette for placeholder content in dark scheme', async () => {
    jest.spyOn(ReactNative, 'useColorScheme').mockReturnValue('dark');
    await render(<PlaceholderScreen title="Weight" description="soon" />);
    expect(screen.getByTestId('placeholder-screen')).toHaveStyle({
      backgroundColor: darkPalette.background,
    });
  });
});
