import { test, expect } from '@playwright/test';
import { runFullWizard, TestProfile } from '../helpers/shiny-helpers';
import { extractResults } from '../helpers/result-extractor';
import { PENSION_MINIMA_LEY97, ESPERANZA_VIDA_M, ESPERANZA_VIDA_F } from '../helpers/constants';

// ============================================================================
// PROFILE G: GENDER IMPACT (Male vs Female)
// ============================================================================
// Same inputs, different gender -> different life expectancy -> different pension
// Born 1961-06-01 (age ~64), retire at 65, 1 year remaining
// Saldo $3M -> after 1yr projection, both above minimum guarantee
//
// Key regulatory basis:
//   Male life expectancy at 65: 17.0 years (CONAPO tables)
//   Female life expectancy at 65: 20.0 years (CONAPO tables)
//   pension = saldo / (esperanza_vida * 12)
//   => Female pension is ~15% lower than Male (longer payout period)
//
// Salary $50K above Fondo threshold ($17,364) -> no Fondo masking
// ============================================================================

const baseInputs = {
  fechaNacimiento: '1961-06-01',
  edadRetiro: 65,
  fechaInicioCotizacion: '2000-01-01',
  salarioMensual: 50000,
  semanasCotizadas: 1300,
  saldoAfore: 3000000,
  aportacionVoluntaria: 0,
  escenario: 'base' as const,
  aforeActual: 'PensionISSSTE',
};

const maleProfile: TestProfile = { ...baseInputs, genero: 'M' };
const femaleProfile: TestProfile = { ...baseInputs, genero: 'F' };

test.describe('Profile G: Gender Impact', () => {
  test('validates life expectancy values from EMSSA 2009 tables', () => {
    expect(ESPERANZA_VIDA_M[65]).toBe(18.4);
    expect(ESPERANZA_VIDA_F[65]).toBe(21.5);
  });

  test('male pension > $12,000 (above minimum, no masking)', async ({ page }) => {
    await runFullWizard(page, maleProfile);
    const result = await extractResults(page);

    console.log(`Profile G Male - Hero: $${result.heroAmount}`);
    // After 1yr projection of $3M at ~3.5% net: ~$3.1M
    // Male pension: ~$3.1M / 204 = ~$15,200
    expect(result.heroAmount).toBeGreaterThan(PENSION_MINIMA_LEY97);
    expect(result.heroAmount).toBeGreaterThan(12000);
    expect(result.heroAmount).toBeLessThan(20000);
  });

  test('female pension > $10,000 (above minimum, no masking)', async ({ page }) => {
    await runFullWizard(page, femaleProfile);
    const result = await extractResults(page);

    console.log(`Profile G Female - Hero: $${result.heroAmount}`);
    // Female pension: ~$3.1M / 240 = ~$12,900
    expect(result.heroAmount).toBeGreaterThan(PENSION_MINIMA_LEY97);
    expect(result.heroAmount).toBeGreaterThan(10000);
    expect(result.heroAmount).toBeLessThan(18000);
  });

  test('female pension is lower than male (longer life expectancy)', async ({ page }) => {
    // Run male first
    await runFullWizard(page, maleProfile);
    const maleResult = await extractResults(page);

    // Run female
    await page.goto('/'); // Reset session
    await runFullWizard(page, femaleProfile);
    const femaleResult = await extractResults(page);

    console.log(`Male: $${maleResult.heroAmount}, Female: $${femaleResult.heroAmount}`);
    console.log(`Difference: $${(maleResult.heroAmount - femaleResult.heroAmount).toFixed(0)}`);

    expect(femaleResult.heroAmount).toBeLessThan(maleResult.heroAmount);
    // Difference should be 10-20% (17/20 = 0.85, so ~15% difference)
    const pctDiff = (maleResult.heroAmount - femaleResult.heroAmount) / maleResult.heroAmount;
    expect(pctDiff).toBeGreaterThan(0.05);
    expect(pctDiff).toBeLessThan(0.25);
  });

  test('neither is Fondo eligible (salary $50K > threshold)', async ({ page }) => {
    await runFullWizard(page, maleProfile);
    const result = await extractResults(page);

    expect(result.fondoEligible).toBe(false);
  });
});
