import { Page } from '@playwright/test';
import { LANDING, WIZARD, STEP1, STEP2, STEP3 } from './selectors';

export interface TestProfile {
  // Step 1
  fechaNacimiento: string;   // YYYY-MM-DD
  genero: 'M' | 'F';
  edadRetiro: number;
  // Step 2
  fechaInicioCotizacion: string; // YYYY-MM-DD
  salarioMensual: number;
  semanasCotizadas: number;
  // Step 3 (Ley 97 only, optional for Ley 73)
  aforeActual?: string;
  saldoAfore?: number;
  aportacionVoluntaria?: number;
  escenario?: 'conservador' | 'base' | 'optimista';
}

/**
 * Wait for Shiny to finish all reactive computations.
 * Uses a polling approach that is more tolerant of brief busy flickers.
 */
export async function waitForShinyIdle(page: Page, timeout = 15000): Promise<void> {
  const start = Date.now();
  let consecutiveIdle = 0;
  while (Date.now() - start < timeout) {
    const isBusy = await page.evaluate(() => {
      return document.querySelector('html')?.classList.contains('shiny-busy') ?? false;
    });
    if (!isBusy) {
      consecutiveIdle++;
      if (consecutiveIdle >= 3) break; // 3 consecutive idle checks (~300ms stable)
    } else {
      consecutiveIdle = 0;
    }
    await page.waitForTimeout(100);
  }
  // Extra safety buffer
  await page.waitForTimeout(300);
}

/**
 * Wait for Shiny to connect (initial page load).
 */
export async function waitForShinyConnected(page: Page, timeout = 60000): Promise<void> {
  await page.waitForFunction(
    () => (window as any).Shiny && (window as any).Shiny.shinyapp && (window as any).Shiny.shinyapp.$socket,
    { timeout }
  );
  await waitForShinyIdle(page);
}

/**
 * Set a Shiny numeric input by clearing and typing the value.
 */
export async function setNumericInput(page: Page, id: string, value: number): Promise<void> {
  const selector = `#${id}`;
  await page.click(selector, { clickCount: 3 }); // Select all
  await page.keyboard.type(String(value));
  await page.keyboard.press('Tab'); // Trigger change event
  await page.waitForTimeout(300);
}

/**
 * Set a Shiny date input by clearing and typing the date.
 * Shiny dateInput internally stores YYYY-MM-DD format.
 * The visible format may differ (dd/mm/yyyy), so we use Shiny binding.
 */
export async function setDateInput(page: Page, id: string, dateStr: string): Promise<void> {
  // Use Shiny's input binding setValue method via jQuery
  await page.evaluate(({ id, dateStr }) => {
    const $ = (window as any).jQuery;
    const Shiny = (window as any).Shiny;
    const el = document.getElementById(id);
    if (!el || !$ || !Shiny) return;

    // Find the Shiny input binding for this element
    const binding = Shiny.inputBindings.getBindings().find(
      (b: any) => b.binding.find(el) === el || $(el).is(b.binding.find(document))
    );

    if (binding) {
      // Use the binding's receiveMessage or setValue
      const $el = $(el);
      // For dateInput, the binding responds to setValue message
      binding.binding.setValue(el, dateStr);
      $el.trigger('change');
    } else {
      // Fallback: set value directly on the input element
      (el as HTMLInputElement).value = dateStr;
      el.dispatchEvent(new Event('change', { bubbles: true }));
      Shiny.setInputValue(id, dateStr);
    }
  }, { id, dateStr });
  await page.waitForTimeout(500);
}

/**
 * Set a Shiny radio button value by clicking the corresponding radio element.
 */
export async function setRadioInput(page: Page, id: string, value: string): Promise<void> {
  const selector = `#${id} input[value="${value}"]`;
  await page.click(selector);
  await page.waitForTimeout(300);
}

/**
 * Set a Shiny selectInput / selectize value.
 */
export async function setSelectInput(page: Page, id: string, value: string): Promise<void> {
  await page.evaluate(({ id, value }) => {
    const $ = (window as any).jQuery;
    const selectizeEl = $(`#${id}`);
    if (selectizeEl.length && selectizeEl[0].selectize) {
      selectizeEl[0].selectize.setValue(value);
    } else {
      // Regular select
      selectizeEl.val(value).trigger('change');
    }
  }, { id, value });
  await page.waitForTimeout(500);
}

/**
 * Click a button and wait for Shiny to settle.
 */
export async function clickAndWait(page: Page, selector: string, waitTime = 2000): Promise<void> {
  await page.click(selector);
  await page.waitForTimeout(waitTime);
  await waitForShinyIdle(page);
}

/**
 * Navigate from landing page to wizard Step 1.
 */
export async function goToWizard(page: Page): Promise<void> {
  await page.goto('/');
  await waitForShinyConnected(page);
  await clickAndWait(page, LANDING.startWizard);
  await page.waitForSelector(WIZARD.step1Panel, { state: 'visible', timeout: 10000 });
}

/**
 * Fill Step 1: Personal Data
 */
export async function fillStep1(page: Page, profile: TestProfile): Promise<void> {
  await setDateInput(page, STEP1.fechaNacimiento, profile.fechaNacimiento);
  await setRadioInput(page, STEP1.genero, profile.genero);
  await setNumericInput(page, STEP1.edadRetiro, profile.edadRetiro);
  await clickAndWait(page, WIZARD.nextStep1);
  await page.waitForSelector(WIZARD.step2Panel, { state: 'visible', timeout: 10000 });
}

/**
 * Fill Step 2: Labor Data
 */
export async function fillStep2(page: Page, profile: TestProfile): Promise<void> {
  await setDateInput(page, STEP2.fechaInicioCotizacion, profile.fechaInicioCotizacion);
  await setNumericInput(page, STEP2.salarioMensual, profile.salarioMensual);
  await setNumericInput(page, STEP2.semanasCotizadas, profile.semanasCotizadas);
  await clickAndWait(page, WIZARD.nextStep2);
  await page.waitForSelector(WIZARD.step3Panel, { state: 'visible', timeout: 10000 });
}

/**
 * Fill Step 3: AFORE & Contributions
 */
export async function fillStep3(page: Page, profile: TestProfile): Promise<void> {
  if (profile.aforeActual) {
    await setSelectInput(page, STEP3.aforeActual, profile.aforeActual);
  }
  if (profile.saldoAfore !== undefined) {
    await setNumericInput(page, STEP3.saldoAfore, profile.saldoAfore);
  }
  if (profile.aportacionVoluntaria !== undefined) {
    await setNumericInput(page, STEP3.aportacionVoluntaria, profile.aportacionVoluntaria);
  }
  if (profile.escenario) {
    await setSelectInput(page, STEP3.escenario, profile.escenario);
  }
}

/**
 * Click Calculate and wait for results to render.
 */
export async function clickCalculate(page: Page): Promise<void> {
  await clickAndWait(page, WIZARD.calcular, 3000);
  await page.waitForSelector(WIZARD.step4Panel, { state: 'visible', timeout: 30000 });
  await waitForShinyIdle(page);
  // Extra wait for result rendering
  await page.waitForTimeout(1000);
}

/**
 * Run complete wizard flow: landing -> step1 -> step2 -> step3 -> calculate -> results
 */
export async function runFullWizard(page: Page, profile: TestProfile): Promise<void> {
  await goToWizard(page);
  await fillStep1(page, profile);
  await fillStep2(page, profile);
  await fillStep3(page, profile);
  await clickCalculate(page);
}
