import { Page } from '@playwright/test';
import { RESULTS } from './selectors';

export interface PensionResult {
  heroAmount: number;
  replacementRate: number;
  fondoEligible: boolean | null;
  minimumApplied: boolean;
  heroLabel: string;
  heroTag: string;
  breakdownRows: { label: string; value: number }[];
}

/**
 * Parse a Mexican currency string to a number.
 * Handles: "$15,000", "$15,000.00", "$8,598.65", "$0", "$15,000 /mes"
 */
export function parseCurrency(text: string): number {
  const cleaned = text
    .replace(/\$/g, '')
    .replace(/,/g, '')
    .replace(/\/mes/gi, '')
    .replace(/mensuales/gi, '')
    .replace(/pesos/gi, '')
    .trim();
  const num = parseFloat(cleaned);
  return isNaN(num) ? 0 : num;
}

/**
 * Parse a percentage string to a number.
 * Handles: "93%", "93% de tu salario", "100%"
 */
export function parsePercentage(text: string): number {
  const match = text.match(/(\d+(?:\.\d+)?)\s*%/);
  return match ? parseFloat(match[1]) : 0;
}

/**
 * Extract all pension results from the Step 4 results page.
 */
export async function extractResults(page: Page): Promise<PensionResult> {
  // Wait for results to be visible
  await page.waitForSelector(RESULTS.resultCardsFrozen, { state: 'visible', timeout: 15000 });

  // Hero pension amount
  const heroAmountText = await page.locator(RESULTS.heroAmount).first().textContent() ?? '$0';
  const heroAmount = parseCurrency(heroAmountText);

  // Replacement rate from badge
  const heroBadgeText = await page.locator(RESULTS.heroBadge).first().textContent() ?? '0%';
  const replacementRate = parsePercentage(heroBadgeText);

  // Hero label (e.g., "TU PENSION ESTIMADA")
  const heroLabel = (await page.locator(RESULTS.heroLabel).first().textContent() ?? '').trim();

  // Hero tag (e.g., "Pension Minima Garantizada", "Incluye Fondo Bienestar")
  const heroTagEl = page.locator(RESULTS.heroTag).first();
  const heroTag = (await heroTagEl.isVisible().catch(() => false))
    ? (await heroTagEl.textContent() ?? '').trim()
    : '';

  // Fondo eligibility
  let fondoEligible: boolean | null = null;
  const fondoEligibleEl = page.locator(RESULTS.fondoEligible);
  const fondoNotEligibleEl = page.locator(RESULTS.fondoNotEligible);
  if (await fondoEligibleEl.count() > 0 && await fondoEligibleEl.first().isVisible()) {
    fondoEligible = true;
  } else if (await fondoNotEligibleEl.count() > 0 && await fondoNotEligibleEl.first().isVisible()) {
    fondoEligible = false;
  }

  // Minimum guarantee applied
  const minimumNoteEl = page.locator(RESULTS.minimumNote);
  const minimumApplied = (await minimumNoteEl.count() > 0) && (await minimumNoteEl.first().isVisible().catch(() => false));

  // Breakdown rows
  const breakdownRows: { label: string; value: number }[] = [];
  const rows = page.locator(RESULTS.breakdownRow);
  const rowCount = await rows.count();
  for (let i = 0; i < rowCount; i++) {
    const row = rows.nth(i);
    const label = (await row.locator(RESULTS.breakdownLabel).textContent() ?? '').trim();
    const valueText = (await row.locator(RESULTS.breakdownValue).textContent() ?? '$0').trim();
    const value = parseCurrency(valueText);
    breakdownRows.push({ label, value });
  }

  return {
    heroAmount,
    replacementRate,
    fondoEligible,
    minimumApplied,
    heroLabel,
    heroTag,
    breakdownRows,
  };
}

/**
 * Get a specific breakdown row value by partial label match.
 */
export function getBreakdownValue(result: PensionResult, labelSubstring: string): number | null {
  const row = result.breakdownRows.find(r =>
    r.label.toLowerCase().includes(labelSubstring.toLowerCase())
  );
  return row ? row.value : null;
}
