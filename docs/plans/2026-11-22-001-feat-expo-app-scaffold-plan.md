---
title: "feat: Scaffold the Expo app shell (Phase 1)"
type: feat
date: 2026-11-22
---

# feat: Scaffold the Expo app shell (Phase 1)

## Summary

Create a running Expo (React Native, TypeScript, Expo Router) app in `app/` with lint, format, type-check and test commands, validated environment loading, query and theme foundations, and five empty tabs. The goal is a CI-verified shell you can open on your phone, so later phases add features without touching tooling.

---

## Problem Frame

The repo has docs, a CI workflow and empty folders, but no app. Phase 2 onward (database, auth, features) all need a working client with checks already in place. Phase 1 exists to remove tooling risk early: version compatibility with Expo Go, a green CI job, and a theme and environment layer that later screens build on.

---

## Requirements

**App shell**
- R1. `app/` contains an Expo app using Expo Router and TypeScript that launches in Expo Go on a real phone.
- R2. Five tabs exist and navigate: Dashboard, Workouts, Nutrition, Weight, Profile. Each shows a themed placeholder screen.

**Quality gates**
- R3. TypeScript runs in strict mode.
- R4. `npm run lint`, `npm run typecheck` and `npm test` exist in `app/` and pass locally.
- R5. The existing `app` job in `.github/workflows/ci.yml` runs and passes on a pull request.

**Foundations**
- R6. Environment variables load through one validated module. A missing or malformed Supabase URL or key fails loudly at startup.
- R7. A query client provider is mounted at the app root, wired to app focus and network state.
- R8. A theme (colors, spacing, type scale) supports light and dark, following the phone's setting.

**Boundaries kept**
- R9. No secrets in `EXPO_PUBLIC_*` variables or committed `.env` files.

---

## Scope Boundaries

- No Supabase client, authentication, data fetching or real screen content (Phases 2 to 5).
- No development build, EAS profiles or store setup. Phase 1 uses Expo Go only.

### Deferred to Follow-Up Work

- Development build when a native module requires it (likely Google sign-in, Phase 3).
- `eas init`, build profiles and update channels (Phase 12).
- End-to-end tests with Maestro (Phase 11).
- App icon, splash screen and app name polish (Phase 10).

---

## Key Technical Decisions

- **Start from the latest stable SDK, with a fallback.** `expo@latest` is SDK 58 (React Native 0.88, minimum Node 22.13). The App Store and Play Store copies of Expo Go can lag a new SDK, so U1 first confirms the phone's Expo Go opens an SDK 58 project. If not, pin the `sdk-57` tag and upgrade later.
- **Project root is `app/`, source in `app/src/`.** Expo Router's routes live in `app/src/app/`, so the repo folder and the router folder share a name. The `src/` layout keeps config files separate from code.
- **Strip the default template.** Begin from `create-expo-app`'s default template and delete its demo screens and components, so only code we own remains.
- **Jest through `jest-expo`.** It handles React Native components, which Vitest does not do well, and Expo documents it as the standard.
- **ESLint flat config extending `eslint-config-expo`, plus Prettier.** This is Expo's documented setup for SDK 53 and later.
- **Environment files live in `app/`.** Expo reads `.env` from the project root, and SDK 58 no longer loads variants like `.env.staging`. The root `.env.example` moves to `app/.env.example`, and README and CLAUDE.md follow.
- **Env access is explicit, then validated.** Expo only inlines `process.env.EXPO_PUBLIC_X` written as a static reference, so each variable is read by name and the object is parsed with Zod.
- **Plain styles driven by theme tokens.** No styling library; a theme hook returns the active palette.
- **CI uses Node 22.** It satisfies SDK 58's minimum and is independent of the local Node 26.

---

## Implementation Units

### U1. Create the Expo project and confirm it runs on the phone

**Goal:** A bare Expo Router + TypeScript app in `app/` that opens in Expo Go.

**Requirements:** R1, R3

**Dependencies:** none

**Files:**
- Create: `app/package.json`, `app/package-lock.json`, `app/app.json`, `app/tsconfig.json`, `app/src/app/_layout.tsx`, `app/src/app/index.tsx`
- Remove: `app/.gitkeep` and the template's demo content

**Approach:**
- Generate the project into `app/`, then remove demo screens, assets and the reset script.
- Turn on `strict` in `tsconfig.json`.
- Before building further, run the dev server and open it from Expo Go on the phone. Record which SDK the store's Expo Go supports; fall back to SDK 57 if SDK 58 is refused.
- Name the app and set the URL scheme in `app.json`.

**Patterns to follow:** Expo's default template conventions for Router layout files.

**Test scenarios:** Test expectation: none -- scaffolding; verified by the launch check below.

**Verification:** The dev server starts and the phone shows the placeholder screen. `npx tsc --noEmit` passes with strict mode on.

### U2. Add lint, format, type-check and test tooling

**Goal:** Three working commands, each enforced by CI later.

**Requirements:** R3, R4

**Dependencies:** U1

**Files:**
- Create: `app/eslint.config.js`, `app/.prettierrc`, `app/jest.config.js` (or the `jest` key in `app/package.json`), `app/src/__tests__/smoke.test.ts`
- Modify: `app/package.json` (scripts `lint`, `format`, `typecheck`, `test`)

**Approach:**
- ESLint flat config extends `eslint-config-expo` with the Prettier plugin.
- `typecheck` runs the TypeScript compiler without emitting.
- Jest uses the `jest-expo` preset; add React Native Testing Library for component tests used in U4.

**Test scenarios:**
- Happy path: the smoke test runs and passes under `npm test`.
- Error path: a deliberately mistyped value fails `npm run typecheck` (checked once, then removed).
- Error path: a lint violation (unused variable) fails `npm run lint` (checked once, then removed).

**Verification:** All three commands exit zero on the clean tree and non-zero on the injected faults.

### U3. Environment module, query provider and theme

**Goal:** The shared foundations that every later screen imports.

**Requirements:** R6, R7, R8, R9

**Dependencies:** U2

**Files:**
- Create: `app/src/lib/env.ts`, `app/src/lib/query-client.tsx`, `app/src/theme/tokens.ts`, `app/src/theme/use-theme.ts`
- Create tests: `app/src/lib/env.test.ts`, `app/src/theme/use-theme.test.ts`
- Move: `.env.example` to `app/.env.example`; update `README.md` and `CLAUDE.md` references
- Modify: `app/src/app/_layout.tsx` (mount the provider)

**Approach:**
- `env.ts` reads the two `EXPO_PUBLIC_SUPABASE_*` variables by static reference and validates them with Zod (URL shape, non-empty key). It throws a clear error naming the missing variable.
- The query provider creates one client and connects TanStack Query's focus state to the app's foreground state and its online state to the network status, so refetching behaves on phones.
- Theme tokens define a light and a dark palette plus spacing and type scale; the hook picks one from the system color scheme.

**Technical design:** Directional only: the layout nests the query provider around the router stack; screens call the theme hook and never import colors directly.

**Test scenarios:**
- Happy path: valid URL and key parse into a typed config object.
- Error path: missing URL throws an error that names `EXPO_PUBLIC_SUPABASE_URL`.
- Error path: malformed URL (not https) is rejected.
- Edge case: key present but empty string is rejected.
- Happy path: theme hook returns the dark palette when the system scheme is dark, light otherwise.
- Integration: rendering the root layout with valid env mounts without throwing.

**Verification:** Tests pass; the app shows a clear startup error with env vars removed and starts normally with them set.

### U4. Five-tab shell with placeholder screens

**Goal:** Navigable tabs for the five product areas.

**Requirements:** R1, R2, R8

**Dependencies:** U3

**Files:**
- Create: `app/src/app/(tabs)/_layout.tsx`, `app/src/app/(tabs)/index.tsx` (Dashboard), `workouts.tsx`, `nutrition.tsx`, `weight.tsx`, `profile.tsx` under the same folder, `app/src/components/placeholder-screen.tsx`
- Create tests: `app/src/app/(tabs)/tabs.test.tsx`

**Approach:**
- One shared placeholder component takes a title and a one-line description of what arrives in which phase.
- Tab bar colors come from the theme hook.
- Dashboard is the initial route.

**Test scenarios:**
- Happy path: the tab layout renders five tabs with the expected titles in order.
- Happy path: each placeholder screen renders its title.
- Edge case: in dark scheme, placeholder text and background use the dark palette.

**Verification:** On the phone, all five tabs open and switch, and the look follows the phone's light or dark setting.

### U5. Make CI green and update project docs

**Goal:** The `app` CI job runs on a pull request and passes.

**Requirements:** R4, R5, R9

**Dependencies:** U1 to U4

**Files:**
- Modify: `.github/workflows/ci.yml`, `docs/TODO.md`, `CLAUDE.md`, `README.md`

**Approach:**
- The workflow already installs, lints, type-checks and tests inside `app/`; confirm the Node 22 setup and lockfile cache path work against the real lockfile.
- Check the secret-scan job behaves on a personal-account repo; if it demands a license key, switch to the CLI form of the scanner.
- Tick Phase 1 in `docs/TODO.md` and update the Status and Commands sections in `CLAUDE.md`.
- Open a pull request from a feature branch rather than pushing to `main`.

**Test scenarios:** Test expectation: none -- workflow and documentation; verified by the CI run.

**Verification:** Both CI jobs pass on the pull request.

---

## Risks & Dependencies

| Risk | Mitigation |
|---|---|
| Store copy of Expo Go does not support SDK 58 yet | Check first in U1; fall back to the `sdk-57` tag and upgrade later |
| `jest-expo`, Testing Library and React 19.2 version mismatch | Install through `npx expo install` so versions match the SDK; resolve at U2 |
| Secret-scan action requires a license on some account types | Verify on the first run; switch to the scanner's CLI if needed |
| Phone and computer on different networks block Expo Go | Use the same Wi-Fi, or tunnel mode for the first run |
| Local Node 26 differs from CI Node 22 | CI is the source of truth; keep both within SDK 58's supported range |

---

## Sources & Research

- Expo SDK 58 changelog: https://expo.dev/changelog/sdk-58 (React Native 0.88, Node 22.13 minimum, Expo Go store lag noted)
- Expo ESLint guide: https://docs.expo.dev/guides/using-eslint
- Expo unit testing with `jest-expo`: https://docs.expo.dev/develop/unit-testing/
- Expo environment variables: https://docs.expo.dev/guides/environment-variables/ (static `EXPO_PUBLIC_` references; SDK 58 loads only `.env`, `.env.local` and production variants)
- Not verified by search: TanStack Query's React Native focus and online wiring and Zod 4 specifics; confirm against current docs while implementing U3.
