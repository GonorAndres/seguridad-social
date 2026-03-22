import { test, expect } from '@playwright/test';
import { runFullWizard, TestProfile } from '../helpers/shiny-helpers';
import { RESULTS } from '../helpers/selectors';
import { getSemanasMinLey97 } from '../helpers/constants';

// ============================================================================
// PROFILE F: LEY 97 INELIGIBLE (below minimum weeks)
// ============================================================================
// Born 1961-06-01 (age ~64), retire at 65, 1 year remaining
// Only 400 weeks + 52 = 452 << minimum of 875 (for retirement year 2026)
//
// Source: DOF 16/12/2020, transitional schedule
// ============================================================================

test.describe('Profile F: Ley 97 Ineligible', () => {
  const profile: TestProfile = {
    fechaNacimiento: '1961-06-01',
    genero: 'M',
    edadRetiro: 65,
    fechaInicioCotizacion: '2000-01-01',
    salarioMensual: 15000,
    semanasCotizadas: 400,
    saldoAfore: 100000,
    aportacionVoluntaria: 0,
    escenario: 'base',
    aforeActual: 'PensionISSSTE',
  };

  test('validates transitional minimum weeks calculation', () => {
    expect(getSemanasMinLey97(2025)).toBe(850);
    expect(getSemanasMinLey97(2026)).toBe(875);
    expect(getSemanasMinLey97(2031)).toBe(1000);
  });

  test('452 weeks is below 2026 minimum of 875', () => {
    const semanasAlRetiro = profile.semanasCotizadas + 52;
    const minSemanas = getSemanasMinLey97(2026);
    expect(semanasAlRetiro).toBe(452);
    expect(semanasAlRetiro).toBeLessThan(minSemanas);
  });

  test('app renders results (may show ineligibility notice)', async ({ page }) => {
    await runFullWizard(page, profile);

    // The app should still advance to Step 4
    // Check if result cards exist or if there's an ineligibility message
    const step4Visible = await page.locator('#step4_panel').isVisible();
    expect(step4Visible).toBe(true);

    // Try to find the hero amount or ineligibility text
    const heroVisible = await page.locator(RESULTS.heroAmount).first().isVisible().catch(() => false);
    if (heroVisible) {
      const heroText = await page.locator(RESULTS.heroAmount).first().textContent();
      console.log(`Profile F - Hero text: "${heroText}"`);
      // If hero shows an amount, it should be the minimum guarantee or $0
    } else {
      console.log(`Profile F - No hero amount visible (likely ineligibility display)`);
    }

    // Check page content for ineligibility-related text
    const pageText = await page.locator('#step4_panel').textContent();
    console.log(`Profile F - Step 4 contains "semanas": ${pageText?.includes('semanas')}`);
    console.log(`Profile F - Step 4 contains "elegible": ${pageText?.toLowerCase().includes('elegible')}`);
  });
});
