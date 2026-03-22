import { test, expect } from '@playwright/test';
import {
  fillStep1,
  fillStep2,
  waitForShinyIdle,
  waitForShinyConnected,
  setDateInput,
  clickAndWait,
  TestProfile,
} from '../helpers/shiny-helpers';
import { LANDING, WIZARD, STEP2, STEP3, SLIDERS } from '../helpers/selectors';

// ============================================================================
// WIZARD NAVIGATION & REGIME DETECTION
// ============================================================================

test.describe('Wizard Flow', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForShinyConnected(page);
  });

  test('landing page loads with hero and CTA', async ({ page }) => {
    await expect(page.locator(LANDING.heroSection)).toBeVisible();
    await expect(page.locator(LANDING.startWizard)).toBeVisible();
  });

  test('clicking CTA navigates to wizard Step 1', async ({ page }) => {
    await clickAndWait(page, LANDING.startWizard);
    await expect(page.locator(WIZARD.step1Panel)).toBeVisible();
  });

  test('can navigate forward and backward through steps', async ({ page }) => {
    await clickAndWait(page, LANDING.startWizard);
    await expect(page.locator(WIZARD.step1Panel)).toBeVisible();

    // Step 1 -> Step 2
    const ley73Profile: TestProfile = {
      fechaNacimiento: '1961-06-01',
      genero: 'M',
      edadRetiro: 65,
      fechaInicioCotizacion: '1990-01-01',
      salarioMensual: 10000,
      semanasCotizadas: 1500,
    };
    await fillStep1(page, ley73Profile);
    await expect(page.locator(WIZARD.step2Panel)).toBeVisible();

    // Step 2 -> Step 1 (back)
    await clickAndWait(page, WIZARD.prevStep2);
    await expect(page.locator(WIZARD.step1Panel)).toBeVisible();
  });
});

// ============================================================================
// REGIME DETECTION
// ============================================================================

test.describe('Regime Detection', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForShinyConnected(page);
    await clickAndWait(page, LANDING.startWizard);
  });

  test('auto-detects Ley 73 for start date before 1997-07-01', async ({ page }) => {
    const profile: TestProfile = {
      fechaNacimiento: '1961-06-01',
      genero: 'M',
      edadRetiro: 65,
      fechaInicioCotizacion: '1990-01-01',
      salarioMensual: 10000,
      semanasCotizadas: 1500,
    };

    await fillStep1(page, profile);
    await setDateInput(page, 'fecha_inicio_cotizacion', profile.fechaInicioCotizacion);
    await waitForShinyIdle(page);

    // Verify regime badge shows Ley 73
    const badgeText = await page.locator(STEP2.regimenBadge).textContent();
    expect(badgeText?.toLowerCase()).toContain('ley 73');
  });

  test('auto-detects Ley 97 for start date on or after 1997-07-01', async ({ page }) => {
    const profile: TestProfile = {
      fechaNacimiento: '1970-01-01',
      genero: 'M',
      edadRetiro: 65,
      fechaInicioCotizacion: '2000-01-01',
      salarioMensual: 15000,
      semanasCotizadas: 1000,
    };

    await fillStep1(page, profile);
    await setDateInput(page, 'fecha_inicio_cotizacion', profile.fechaInicioCotizacion);
    await waitForShinyIdle(page);

    const badgeText = await page.locator(STEP2.regimenBadge).textContent();
    expect(badgeText?.toLowerCase()).toContain('ley 97');
  });

  test('AFORE fields dimmed for Ley 73 workers', async ({ page }) => {
    const profile: TestProfile = {
      fechaNacimiento: '1961-06-01',
      genero: 'M',
      edadRetiro: 65,
      fechaInicioCotizacion: '1990-01-01',
      salarioMensual: 10000,
      semanasCotizadas: 1500,
    };

    await fillStep1(page, profile);
    await fillStep2(page, profile);

    // AFORE fields should have dimmed-fields class
    const dimmedClass = await page.locator(STEP3.aforeFieldsContainer)
      .evaluate(el => el.classList.contains('dimmed-fields'));
    expect(dimmedClass).toBe(true);
  });

  test('sensitivity sliders hidden for Ley 73 after calculation', async ({ page }) => {
    const profile: TestProfile = {
      fechaNacimiento: '1961-06-01',
      genero: 'M',
      edadRetiro: 65,
      fechaInicioCotizacion: '1990-01-01',
      salarioMensual: 10000,
      semanasCotizadas: 1500,
    };

    await fillStep1(page, profile);
    await fillStep2(page, profile);
    // Skip Step 3 AFORE details for Ley 73
    await clickAndWait(page, WIZARD.calcular, 3000);
    await page.waitForSelector(WIZARD.step4Panel, { state: 'visible', timeout: 30000 });
    await waitForShinyIdle(page);

    // Voluntary slider and AFORE selector should be hidden
    await expect(page.locator(SLIDERS.volSliderCol)).toBeHidden();
    await expect(page.locator(SLIDERS.aforeSliderRow)).toBeHidden();
  });
});
