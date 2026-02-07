# ============================================================================
# Backend Test Agent B - Financial Audit Tests
# ============================================================================

# Set working directory
setwd("/home/andre/seguridad_social/fondo_bienestar")

# Load required files
source("global.R")

# Output file
output_file <- "subagents_outputs/backend_test_agent_B.md"
sink(output_file)

cat("# Backend Test Agent B - Financial Audit Report\n\n")
cat("**Date:** ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ============================================================================
# TEST 1: LEY 73 WORKER
# ============================================================================
cat("## Test 1: Ley 73 Worker (Born before 1973)\n\n")
cat("### Input Parameters\n")
cat("- SBC diario: $500\n")
cat("- Semanas cotizadas: 1,500\n")
cat("- Edad: 62\n\n")

result73 <- calculate_ley73_pension(
  sbc_promedio_diario = 500,
  semanas = 1500,
  edad = 62
)

cat("### Function Results\n")
cat("| Field | Value |\n")
cat("|-------|-------|\n")
cat("| Elegible | ", result73$elegible, " |\n")
cat("| Tipo pension | ", result73$tipo_pension, " |\n")
cat("| Grupo salarial | ", round(result73$grupo_salarial, 4), " |\n")
cat("| Cuantia basica | ", result73$cuantia_basica, " |\n")
cat("| Incremento anual | ", result73$incremento_anual, " |\n")
cat("| N. incrementos | ", result73$n_incrementos, " |\n")
cat("| Total incrementos | ", round(result73$total_incrementos, 4), " |\n")
cat("| Porcentaje total | ", round(result73$porcentaje_total, 4), " |\n")
cat("| Factor edad | ", result73$factor_edad, " |\n")
cat("| **Pension mensual** | **$", format(round(result73$pension_mensual, 2), big.mark=","), "** |\n")
cat("| Pension sin minimo | $", format(round(result73$pension_sin_minimo, 2), big.mark=","), " |\n")
cat("| Tasa reemplazo | ", round(result73$tasa_reemplazo * 100, 2), "% |\n")
cat("| Aplico minimo | ", result73$aplico_minimo, " |\n\n")

cat("### Manual Verification\n\n")
SM_DIARIO <- 278.80
SBC_DIARIO <- 500
SEMANAS <- 1500
EDAD <- 62

grupo_salarial_manual <- SBC_DIARIO / SM_DIARIO
cat("1. **Grupo salarial:** 500 / 278.80 = ", round(grupo_salarial_manual, 4), "\n")

cat("2. **Tabla Art 167 lookup:** Grupo 1.76-2.00 -> cuantia=0.4267, incremento=0.01615\n")

n_incrementos_manual <- floor((SEMANAS - 500) / 52)
cat("3. **Incrementos:** floor((1500-500)/52) = ", n_incrementos_manual, " anos\n")

total_incrementos_manual <- n_incrementos_manual * 0.01615
cat("4. **Total incrementos:** 19 * 0.01615 = ", round(total_incrementos_manual, 4), "\n")

porcentaje_manual <- min(0.4267 + total_incrementos_manual, 1.0)
cat("5. **Porcentaje total:** min(0.4267 + 0.30685, 1.0) = ", round(porcentaje_manual, 4), "\n")

cat("6. **Factor cesantia (edad 62):** 0.85\n")

pension_diaria <- SBC_DIARIO * porcentaje_manual * 0.85
pension_mensual_manual <- pension_diaria * 30
cat("7. **Pension diaria:** 500 * ", round(porcentaje_manual, 4), " * 0.85 = ", round(pension_diaria, 2), "\n")
cat("8. **Pension mensual:** ", round(pension_diaria, 2), " * 30 = $", format(round(pension_mensual_manual, 2), big.mark=","), "\n")

pension_minima <- SM_DIARIO * 30
cat("9. **Pension minima (1 SM):** 278.80 * 30 = $", format(round(pension_minima, 2), big.mark=","), "\n")
cat("10. **Pension final:** max(", round(pension_mensual_manual, 2), ", ", round(pension_minima, 2), ") = $", format(round(max(pension_mensual_manual, pension_minima), 2), big.mark=","), "\n\n")

discrepancy1 <- abs(result73$pension_mensual - pension_mensual_manual) / pension_mensual_manual * 100
cat("### Verification Result\n")
cat("- Code result: $", format(round(result73$pension_mensual, 2), big.mark=","), "\n")
cat("- Manual result: $", format(round(pension_mensual_manual, 2), big.mark=","), "\n")
cat("- **Discrepancy:** ", round(discrepancy1, 2), "%\n")
if (discrepancy1 > 5) {
  cat("- **Status:** FAIL - Discrepancy exceeds 5%\n\n")
} else {
  cat("- **Status:** PASS - Within acceptable tolerance\n\n")
}

# ============================================================================
# TEST 2: Just reaching Fondo threshold
# ============================================================================
cat("---\n\n")
cat("## Test 2: Just Reaching Fondo Threshold\n\n")
cat("### Input Parameters\n")
cat("- Age: 45\n")
cat("- Salary: $17,000/month (just below $17,364 threshold)\n")
cat("- AFORE balance: $200,000\n")
cat("- Semanas: 800\n")
cat("- Retire at 65\n")
cat("- Voluntary: $1,000/month\n\n")

result2 <- calculate_pension_with_fondo(
  saldo_actual = 200000,
  salario_mensual = 17000,
  edad_actual = 45,
  edad_retiro = 65,
  semanas_actuales = 800,
  genero = "M",
  aportacion_voluntaria = 1000,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

cat("### Function Results\n\n")
cat("**Eligibility:**\n")
cat("- Fondo elegible: ", result2$fondo_bienestar$elegible, "\n")
cat("- Umbral used: $", format(result2$fondo_bienestar$umbral, big.mark=","), "\n")
cat("- Semanas al retiro: ", result2$entrada$semanas_al_retiro, "\n\n")

cat("**Scenario 1 - Solo Sistema (no voluntary):**\n")
cat("- Saldo proyectado: $", format(round(result2$solo_sistema$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Pension mensual: $", format(round(result2$solo_sistema$pension_mensual, 2), big.mark=","), "\n")
cat("- Tasa reemplazo: ", round(result2$solo_sistema$tasa_reemplazo * 100, 2), "%\n\n")

cat("**Scenario 2 - Con Fondo Bienestar:**\n")
cat("- Pension AFORE: $", format(round(result2$con_fondo$pension_afore, 2), big.mark=","), "\n")
cat("- Complemento Fondo: $", format(round(result2$con_fondo$complemento, 2), big.mark=","), "\n")
cat("- **Pension Total:** $", format(round(result2$con_fondo$pension_total, 2), big.mark=","), "\n")
cat("- Tasa reemplazo: ", round(result2$con_fondo$tasa_reemplazo * 100, 2), "%\n\n")

cat("**Scenario 3 - Con Acciones (voluntary contributions):**\n")
cat("- Saldo proyectado: $", format(round(result2$con_acciones$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Pension AFORE: $", format(round(result2$con_acciones$pension_afore, 2), big.mark=","), "\n")
cat("- Complemento Fondo: $", format(round(result2$con_acciones$complemento_fondo, 2), big.mark=","), "\n")
cat("- **Pension Total:** $", format(round(result2$con_acciones$pension_total, 2), big.mark=","), "\n\n")

cat("### Manual Verification\n\n")

# Manual calculation for Test 2
anios <- 20
saldo_inicial <- 200000
salario <- 17000
rendimiento <- 0.04  # base scenario
comision <- 0.0051  # XXI Banorte
r_neto <- rendimiento - comision

# Aportacion obligatoria (2025: 7.75% patron + 1.125% trabajador + 0.225% gobierno = ~9.1%)
tasa_obligatoria <- 0.0775 + 0.01125 + 0.00225
aport_obligatoria <- salario * tasa_obligatoria
aport_voluntaria <- 1000
aport_total <- aport_obligatoria + aport_voluntaria

cat("**Contribution calculations:**\n")
cat("- Tasa obligatoria (2025): 7.75% + 1.125% + 0.225% = ", round(tasa_obligatoria * 100, 2), "%\n")
cat("- Aportacion obligatoria: $17,000 * ", round(tasa_obligatoria, 4), " = $", format(round(aport_obligatoria, 2), big.mark=","), "\n")
cat("- Aportacion voluntaria: $1,000\n")
cat("- Aportacion total mensual: $", format(round(aport_total, 2), big.mark=","), "\n\n")

# Future value calculation
r_mensual <- (1 + r_neto)^(1/12) - 1
meses <- anios * 12

fv_saldo <- saldo_inicial * (1 + r_neto)^anios
fv_aportaciones <- aport_total * ((1 + r_mensual)^meses - 1) / r_mensual
saldo_final_manual <- fv_saldo + fv_aportaciones

cat("**Projected balance:**\n")
cat("- Rendimiento neto: ", round(r_neto * 100, 2), "%\n")
cat("- FV saldo inicial: $200,000 * (1.0349)^20 = $", format(round(fv_saldo, 2), big.mark=","), "\n")
cat("- FV aportaciones: $", format(round(fv_aportaciones, 2), big.mark=","), "\n")
cat("- **Saldo final manual:** $", format(round(saldo_final_manual, 2), big.mark=","), "\n\n")

# Pension calculation
esperanza_vida <- 17.0  # hombre 65 anos
pension_mensual_manual2 <- saldo_final_manual / (esperanza_vida * 12)

cat("**Pension calculation:**\n")
cat("- Esperanza de vida (hombre 65): ", esperanza_vida, " anos\n")
cat("- Meses esperados: ", esperanza_vida * 12, "\n")
cat("- **Pension mensual manual:** $", format(round(pension_mensual_manual2, 2), big.mark=","), "\n\n")

# Fondo complement (if eligible)
pension_objetivo <- min(salario, 17364)  # min of salary and threshold
complemento_manual <- max(0, pension_objetivo - pension_mensual_manual2)
pension_total_manual <- pension_mensual_manual2 + complemento_manual

cat("**Fondo Bienestar:**\n")
cat("- Pension objetivo: min($17,000, $17,364) = $", format(pension_objetivo, big.mark=","), "\n")
cat("- Complemento: max(0, $17,000 - $", format(round(pension_mensual_manual2, 2), big.mark=","), ") = $", format(round(complemento_manual, 2), big.mark=","), "\n")
cat("- **Pension total con Fondo:** $", format(round(pension_total_manual, 2), big.mark=","), "\n\n")

discrepancy2 <- abs(result2$con_acciones$saldo_proyectado - saldo_final_manual) / saldo_final_manual * 100
cat("### Verification Result\n")
cat("- Code saldo: $", format(round(result2$con_acciones$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Manual saldo: $", format(round(saldo_final_manual, 2), big.mark=","), "\n")
cat("- **Discrepancy (saldo):** ", round(discrepancy2, 2), "%\n")
cat("- Expected Fondo eligibility: TRUE\n")
cat("- Actual Fondo eligibility: ", result2$fondo_bienestar$elegible, "\n")
if (result2$fondo_bienestar$elegible && discrepancy2 <= 5) {
  cat("- **Status:** PASS\n\n")
} else {
  cat("- **Status:** FAIL\n\n")
}

# ============================================================================
# TEST 3: Just above Fondo threshold
# ============================================================================
cat("---\n\n")
cat("## Test 3: Just Above Fondo Threshold (NOT Eligible)\n\n")
cat("### Input Parameters\n")
cat("- Age: 45\n")
cat("- Salary: $18,000/month (above $17,364 threshold)\n")
cat("- AFORE balance: $200,000\n")
cat("- Semanas: 800\n")
cat("- Retire at 65\n")
cat("- Voluntary: $1,000/month\n\n")

result3 <- calculate_pension_with_fondo(
  saldo_actual = 200000,
  salario_mensual = 18000,
  edad_actual = 45,
  edad_retiro = 65,
  semanas_actuales = 800,
  genero = "M",
  aportacion_voluntaria = 1000,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

cat("### Function Results\n\n")
cat("**Eligibility:**\n")
cat("- Fondo elegible: ", result3$fondo_bienestar$elegible, "\n")
cat("- Razon no elegible: ", result3$fondo_bienestar$razon_no_elegible, "\n")
cat("- Umbral used: $", format(result3$fondo_bienestar$umbral, big.mark=","), "\n\n")

cat("**Pension Results:**\n")
cat("- Pension AFORE (con acciones): $", format(round(result3$con_acciones$pension_afore, 2), big.mark=","), "\n")
cat("- Complemento Fondo: $", format(round(result3$con_acciones$complemento_fondo, 2), big.mark=","), "\n")
cat("- Pension Total: $", format(round(result3$con_acciones$pension_total, 2), big.mark=","), "\n\n")

cat("### Verification Result\n")
cat("- Expected Fondo eligibility: FALSE (salary > threshold)\n")
cat("- Actual Fondo eligibility: ", result3$fondo_bienestar$elegible, "\n")
if (!result3$fondo_bienestar$elegible) {
  cat("- **Status:** PASS - Correctly rejected due to salary above threshold\n\n")
} else {
  cat("- **Status:** FAIL - Should NOT be eligible\n\n")
}

# ============================================================================
# TEST 4: Maximum voluntary contributor
# ============================================================================
cat("---\n\n")
cat("## Test 4: Maximum Voluntary Contributor\n\n")
cat("### Input Parameters\n")
cat("- Age: 30\n")
cat("- Salary: $25,000/month\n")
cat("- AFORE balance: $100,000\n")
cat("- Semanas: 400\n")
cat("- Retire at 65 (35 years)\n")
cat("- Voluntary: $10,000/month (aggressive saver)\n\n")

result4 <- calculate_pension_with_fondo(
  saldo_actual = 100000,
  salario_mensual = 25000,
  edad_actual = 30,
  edad_retiro = 65,
  semanas_actuales = 400,
  genero = "M",
  aportacion_voluntaria = 10000,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

cat("### Function Results\n\n")
cat("**Eligibility:**\n")
cat("- Fondo elegible: ", result4$fondo_bienestar$elegible, "\n")
cat("- Semanas al retiro: ", result4$entrada$semanas_al_retiro, "\n\n")

cat("**Pension Results:**\n")
cat("- Saldo proyectado: $", format(round(result4$con_acciones$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Pension AFORE: $", format(round(result4$con_acciones$pension_afore, 2), big.mark=","), "\n")
cat("- Tasa reemplazo: ", round(result4$con_acciones$pension_afore / 25000 * 100, 2), "%\n\n")

cat("### Manual Verification\n\n")

# Manual calculation for Test 4
anios4 <- 35
saldo_inicial4 <- 100000
salario4 <- 25000
r_neto4 <- 0.04 - 0.0051

tasa_obligatoria4 <- 0.0775 + 0.01125 + 0.00225
aport_obligatoria4 <- salario4 * tasa_obligatoria4
aport_voluntaria4 <- 10000
aport_total4 <- aport_obligatoria4 + aport_voluntaria4

r_mensual4 <- (1 + r_neto4)^(1/12) - 1
meses4 <- anios4 * 12

fv_saldo4 <- saldo_inicial4 * (1 + r_neto4)^anios4
fv_aportaciones4 <- aport_total4 * ((1 + r_mensual4)^meses4 - 1) / r_mensual4
saldo_final_manual4 <- fv_saldo4 + fv_aportaciones4

cat("**Contribution calculations:**\n")
cat("- Aportacion obligatoria: $", format(round(aport_obligatoria4, 2), big.mark=","), "\n")
cat("- Aportacion voluntaria: $10,000\n")
cat("- Aportacion total mensual: $", format(round(aport_total4, 2), big.mark=","), "\n\n")

cat("**Projected balance (35 years):**\n")
cat("- FV saldo inicial: $", format(round(fv_saldo4, 2), big.mark=","), "\n")
cat("- FV aportaciones: $", format(round(fv_aportaciones4, 2), big.mark=","), "\n")
cat("- **Saldo final manual:** $", format(round(saldo_final_manual4, 2), big.mark=","), "\n\n")

esperanza_vida4 <- 17.0
pension_mensual_manual4 <- saldo_final_manual4 / (esperanza_vida4 * 12)

cat("**Pension calculation:**\n")
cat("- **Pension mensual manual:** $", format(round(pension_mensual_manual4, 2), big.mark=","), "\n\n")

discrepancy4 <- abs(result4$con_acciones$saldo_proyectado - saldo_final_manual4) / saldo_final_manual4 * 100
cat("### Verification Result\n")
cat("- Code saldo: $", format(round(result4$con_acciones$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Manual saldo: $", format(round(saldo_final_manual4, 2), big.mark=","), "\n")
cat("- **Discrepancy:** ", round(discrepancy4, 2), "%\n")
if (discrepancy4 <= 5) {
  cat("- **Status:** PASS\n\n")
} else {
  cat("- **Status:** FAIL\n\n")
}

# ============================================================================
# TEST 5: Near retirement
# ============================================================================
cat("---\n\n")
cat("## Test 5: Near Retirement\n\n")
cat("### Input Parameters\n")
cat("- Age: 60\n")
cat("- Salary: $22,000/month\n")
cat("- AFORE balance: $600,000\n")
cat("- Semanas: 1,800\n")
cat("- Retire at 65 (5 years)\n")
cat("- Voluntary: $3,000/month\n\n")

result5 <- calculate_pension_with_fondo(
  saldo_actual = 600000,
  salario_mensual = 22000,
  edad_actual = 60,
  edad_retiro = 65,
  semanas_actuales = 1800,
  genero = "M",
  aportacion_voluntaria = 3000,
  afore_nombre = "XXI Banorte",
  escenario = "base"
)

cat("### Function Results\n\n")
cat("**Eligibility:**\n")
cat("- Fondo elegible: ", result5$fondo_bienestar$elegible, "\n")
cat("- Semanas al retiro: ", result5$entrada$semanas_al_retiro, "\n\n")

cat("**Solo Sistema:**\n")
cat("- Saldo proyectado: $", format(round(result5$solo_sistema$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Pension mensual: $", format(round(result5$solo_sistema$pension_mensual, 2), big.mark=","), "\n\n")

cat("**Con Acciones (voluntary):**\n")
cat("- Saldo proyectado: $", format(round(result5$con_acciones$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Pension AFORE: $", format(round(result5$con_acciones$pension_afore, 2), big.mark=","), "\n")
cat("- Complemento Fondo: $", format(round(result5$con_acciones$complemento_fondo, 2), big.mark=","), "\n")
cat("- Pension Total: $", format(round(result5$con_acciones$pension_total, 2), big.mark=","), "\n\n")

cat("### Manual Verification\n\n")

# Manual calculation for Test 5
anios5 <- 5
saldo_inicial5 <- 600000
salario5 <- 22000
r_neto5 <- 0.04 - 0.0051

tasa_obligatoria5 <- 0.0775 + 0.01125 + 0.00225
aport_obligatoria5 <- salario5 * tasa_obligatoria5
aport_voluntaria5 <- 3000
aport_total5 <- aport_obligatoria5 + aport_voluntaria5

r_mensual5 <- (1 + r_neto5)^(1/12) - 1
meses5 <- anios5 * 12

fv_saldo5 <- saldo_inicial5 * (1 + r_neto5)^anios5
fv_aportaciones5 <- aport_total5 * ((1 + r_mensual5)^meses5 - 1) / r_mensual5
saldo_final_manual5 <- fv_saldo5 + fv_aportaciones5

cat("**Contribution calculations:**\n")
cat("- Aportacion obligatoria: $", format(round(aport_obligatoria5, 2), big.mark=","), "\n")
cat("- Aportacion voluntaria: $3,000\n")
cat("- Aportacion total mensual: $", format(round(aport_total5, 2), big.mark=","), "\n\n")

cat("**Projected balance (5 years):**\n")
cat("- FV saldo inicial: $", format(round(fv_saldo5, 2), big.mark=","), "\n")
cat("- FV aportaciones: $", format(round(fv_aportaciones5, 2), big.mark=","), "\n")
cat("- **Saldo final manual:** $", format(round(saldo_final_manual5, 2), big.mark=","), "\n\n")

esperanza_vida5 <- 17.0
pension_mensual_manual5 <- saldo_final_manual5 / (esperanza_vida5 * 12)

cat("**Pension calculation:**\n")
cat("- **Pension mensual manual:** $", format(round(pension_mensual_manual5, 2), big.mark=","), "\n\n")

discrepancy5 <- abs(result5$con_acciones$saldo_proyectado - saldo_final_manual5) / saldo_final_manual5 * 100
cat("### Verification Result\n")
cat("- Code saldo: $", format(round(result5$con_acciones$saldo_proyectado, 2), big.mark=","), "\n")
cat("- Manual saldo: $", format(round(saldo_final_manual5, 2), big.mark=","), "\n")
cat("- **Discrepancy:** ", round(discrepancy5, 2), "%\n")
if (discrepancy5 <= 5) {
  cat("- **Status:** PASS\n\n")
} else {
  cat("- **Status:** FAIL\n\n")
}

# ============================================================================
# SUMMARY
# ============================================================================
cat("---\n\n")
cat("## Summary\n\n")

cat("| Test | Description | Status |\n")
cat("|------|-------------|--------|\n")

# Test 1
if (discrepancy1 <= 5) {
  cat("| 1 | Ley 73 Worker | PASS |\n")
} else {
  cat("| 1 | Ley 73 Worker | FAIL |\n")
}

# Test 2
if (result2$fondo_bienestar$elegible && discrepancy2 <= 5) {
  cat("| 2 | Just Reaching Fondo Threshold | PASS |\n")
} else {
  cat("| 2 | Just Reaching Fondo Threshold | FAIL |\n")
}

# Test 3
if (!result3$fondo_bienestar$elegible) {
  cat("| 3 | Just Above Fondo Threshold | PASS |\n")
} else {
  cat("| 3 | Just Above Fondo Threshold | FAIL |\n")
}

# Test 4
if (discrepancy4 <= 5) {
  cat("| 4 | Maximum Voluntary Contributor | PASS |\n")
} else {
  cat("| 4 | Maximum Voluntary Contributor | FAIL |\n")
}

# Test 5
if (discrepancy5 <= 5) {
  cat("| 5 | Near Retirement | PASS |\n")
} else {
  cat("| 5 | Near Retirement | FAIL |\n")
}

cat("\n---\n")
cat("\n**Report generated by Backend Test Agent B**\n")

sink()
cat("Report written to:", output_file, "\n")
