import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: [['html'], ['list']],
  timeout: 120_000,
  expect: {
    timeout: 15_000,
  },
  use: {
    baseURL: process.env.APP_URL || 'http://localhost:3838',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    actionTimeout: 15_000,
    navigationTimeout: 60_000,
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
  webServer: {
    command: 'R -e "shiny::runApp(\'.\', host=\'0.0.0.0\', port=3838, launch.browser=FALSE)"',
    port: 3838,
    cwd: '..',
    reuseExistingServer: !process.env.CI,
    timeout: 60_000,
  },
});
