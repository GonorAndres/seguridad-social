# ============================================================
# FRONTEND-BACKEND INTEGRATION TEST
# Simulates the unified recalculation observer logic
# ============================================================

# --- Setup (same as test preamble) ---
data_dir <- "data"; r_dir <- "R"
articulo_167_tabla <<- read.csv(file.path(data_dir, "articulo_167_tabla.csv"), stringsAsFactors = FALSE)
uma_data <<- read.csv(file.path(data_dir, "uma_historico.csv"), stringsAsFactors = FALSE)
salario_minimo_data <<- read.csv(file.path(data_dir, "salario_minimo.csv"), stringsAsFactors = FALSE)
afore_data <<- read.csv(file.path(data_dir, "afore_comisiones.csv"), stringsAsFactors = FALSE)

ANIO_ACTUAL <<- 2025; UMA_DIARIA_2025 <<- 113.14; UMA_MENSUAL_2025 <<- 3439.46
SM_DIARIO_2025 <<- 278.80; SM_MENSUAL_2025 <<- 8474.52
UMBRAL_FONDO_BIENESTAR_2025 <<- 17364; TOPE_SBC_DIARIO <<- UMA_DIARIA_2025 * 25
RENDIMIENTO_CONSERVADOR <<- 0.03; RENDIMIENTO_BASE <<- 0.04; RENDIMIENTO_OPTIMISTA <<- 0.05
FACTORES_CESANTIA <<- c("60"=0.75, "61"=0.80, "62"=0.85, "63"=0.90, "64"=0.95, "65"=1.00)
format_currency <<- function(x) paste0("$", format(round(x,2), big.mark=",", nsmall=2))
format_percent <<- function(x) paste0(round(x*100,1), "%")
get_umbral_fondo_bienestar <<- function(anio) {
  umbrales <- c("2024"=16777.68, "2025"=17364, "2026"=18050)
  if (as.character(anio) %in% names(umbrales)) return(umbrales[as.character(anio)])
  return(umbrales[length(umbrales)])
}
`%||%` <<- function(x,y) if (is.null(x)||length(x)==0) y else x
source(file.path(r_dir, "data_tables.R"))
source(file.path(r_dir, "calculations.R"))
source(file.path(r_dir, "fondo_bienestar.R"))

cat("===== FRONTEND-BACKEND SENSITIVITY PIPELINE TEST =====\n\n")
pass_count <- 0; fail_count <- 0

check <- function(name, condition) {
  if (condition) {
    cat(sprintf("  PASS: %s\n", name))
    pass_count <<- pass_count + 1
  } else {
    cat(sprintf("  FAIL: %s\n", name))
    fail_count <<- fail_count + 1
  }
}

# ============================================================
# TEST 1: Ley 97 -- Initial calc + slider changes update results
# ============================================================
cat("--- TEST 1: Ley 97 Sensitivity Pipeline ---\n")

# Step 1: Simulate "Calculate" button click
res_original <- calculate_pension_with_fondo(
  saldo_actual = 300000, salario_mensual = 15000,
  edad_actual = 45, edad_retiro = 65,
  semanas_actuales = 800, genero = "M",
  aportacion_voluntaria = 1000,
  afore_nombre = "XXI Banorte", escenario = "base"
)
res_original$regimen <- "ley97"
res_original$fondo_aplica <- TRUE

cat(sprintf("  Original pension: %s/mes\n", format_currency(res_original$solo_sistema$pension_mensual)))
cat(sprintf("  Original saldo proyectado: %s\n", format_currency(res_original$solo_sistema$saldo_proyectado)))

# Step 2: Simulate changing voluntary contribution slider to $3000
res_vol_changed <- calculate_pension_with_fondo(
  saldo_actual = res_original$entrada$saldo_actual,
  salario_mensual = res_original$entrada$salario_mensual,
  edad_actual = res_original$entrada$edad_actual,
  edad_retiro = 65, semanas_actuales = 800,
  genero = "M", aportacion_voluntaria = 3000,
  afore_nombre = "XXI Banorte", escenario = "base"
)
res_vol_changed$regimen <- "ley97"

cat(sprintf("  After vol->3000: pension %s, saldo %s\n",
  format_currency(res_vol_changed$con_acciones$pension_afore),
  format_currency(res_vol_changed$con_acciones$saldo_proyectado)))

check("Vol increase -> higher con_acciones saldo",
  res_vol_changed$con_acciones$saldo_proyectado > res_original$con_acciones$saldo_proyectado)
check("Vol increase -> solo_sistema unchanged",
  res_vol_changed$solo_sistema$saldo_proyectado == res_original$solo_sistema$saldo_proyectado)

# Step 3: Simulate changing AFORE to Coppel
res_afore_changed <- calculate_pension_with_fondo(
  saldo_actual = res_original$entrada$saldo_actual,
  salario_mensual = res_original$entrada$salario_mensual,
  edad_actual = res_original$entrada$edad_actual,
  edad_retiro = 65, semanas_actuales = 800,
  genero = "M", aportacion_voluntaria = 1000,
  afore_nombre = "Coppel", escenario = "base"
)
res_afore_changed$regimen <- "ley97"

cat(sprintf("  After AFORE->Coppel: saldo %s (was %s)\n",
  format_currency(res_afore_changed$solo_sistema$saldo_proyectado),
  format_currency(res_original$solo_sistema$saldo_proyectado)))

check("Different AFORE -> different projected balance",
  res_afore_changed$solo_sistema$saldo_proyectado != res_original$solo_sistema$saldo_proyectado)

# Step 4: Simulate changing retirement age to 60
res_age_changed <- calculate_pension_with_fondo(
  saldo_actual = res_original$entrada$saldo_actual,
  salario_mensual = res_original$entrada$salario_mensual,
  edad_actual = res_original$entrada$edad_actual,
  edad_retiro = 60, semanas_actuales = 800,
  genero = "M", aportacion_voluntaria = 1000,
  afore_nombre = "XXI Banorte", escenario = "base"
)
res_age_changed$regimen <- "ley97"

cat(sprintf("  After age->60: saldo %s (was %s)\n",
  format_currency(res_age_changed$solo_sistema$saldo_proyectado),
  format_currency(res_original$solo_sistema$saldo_proyectado)))

check("Lower retirement age -> lower projected balance",
  res_age_changed$solo_sistema$saldo_proyectado < res_original$solo_sistema$saldo_proyectado)
check("Age change -> entrada$edad_retiro updated",
  res_age_changed$entrada$edad_retiro == 60)

# Step 5: Simulate changing semanas to 500
res_sem_changed <- calculate_pension_with_fondo(
  saldo_actual = res_original$entrada$saldo_actual,
  salario_mensual = res_original$entrada$salario_mensual,
  edad_actual = res_original$entrada$edad_actual,
  edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 1000,
  afore_nombre = "XXI Banorte", escenario = "base"
)

check("500 semanas + 20yr growth -> still eligible",
  unname(res_sem_changed$solo_sistema$pension_mensual) > 0)

# Step 6: Impact label computation
vol_impact <- res_vol_changed$con_acciones$diferencia_vs_base
cat(sprintf("  Vol impact label would show: +%s/mes\n", format_currency(vol_impact)))
check("Vol impact is positive number", vol_impact > 0)

age_saldo_impact <- res_age_changed$solo_sistema$saldo_proyectado - res_original$solo_sistema$saldo_proyectado
age_pension_impact <- res_age_changed$solo_sistema$pension_mensual - res_original$solo_sistema$pension_mensual
cat(sprintf("  Age saldo impact: %s\n", format_currency(age_saldo_impact)))
cat(sprintf("  Age pension impact: %s/mes (may be 0 if both hit pension minima floor)\n",
  format_currency(age_pension_impact)))
check("Age decrease -> lower projected saldo", unname(age_saldo_impact) < 0)
check("Age decrease -> pension impact <= 0 (never increases pension)",
  unname(age_pension_impact) <= 0)

# Step 7: Chart trace data available
check("Original has trayectoria for chart trace 1",
  !is.null(res_original$solo_sistema$trayectoria))
check("Changed result has trayectoria for chart trace 2",
  !is.null(res_vol_changed$solo_sistema$trayectoria))
check("Changed result has con_acciones trayectoria for trace 3",
  !is.null(res_vol_changed$con_acciones$trayectoria))

# ============================================================
# TEST 2: Ley 73 -- Sensitivity pipeline
# ============================================================
cat("\n--- TEST 2: Ley 73 Sensitivity Pipeline ---\n")

sbc_diario <- 15000/30
res73_orig <- list(
  regimen = "ley73",
  pension_base = calculate_ley73_pension(sbc_promedio_diario = sbc_diario, semanas = 1800, edad = 65),
  fondo_aplica = FALSE,
  entrada = list(salario_mensual = 15000, edad_actual = 55, edad_retiro = 65,
                 semanas_actuales = 1280, genero = "M")
)

cat(sprintf("  Original Ley73 pension: %s/mes (factor=%.2f)\n",
  format_currency(res73_orig$pension_base$pension_mensual),
  res73_orig$pension_base$factor_edad))

# Simulate age slider -> 60
edad_slider <- 60
anios_restantes <- max(0, edad_slider - res73_orig$entrada$edad_actual)
semanas_al_retiro <- res73_orig$entrada$semanas_actuales + (anios_restantes * 52)

res73_age60 <- calculate_ley73_pension(
  sbc_promedio_diario = sbc_diario,
  semanas = semanas_al_retiro,
  edad = 60
)
cat(sprintf("  After age->60: pension %s (factor=%.2f, semanas=%d)\n",
  format_currency(res73_age60$pension_mensual), res73_age60$factor_edad, semanas_al_retiro))

check("Ley73 age 60 -> lower pension than 65",
  unname(res73_age60$pension_mensual) < unname(res73_orig$pension_base$pension_mensual))
check("Ley73 age 60 -> cesantia factor is 0.75",
  unname(res73_age60$factor_edad) == 0.75)

# Simulate semanas slider -> 2000
semanas_slider <- 2000
anios_restantes_orig <- max(0, res73_orig$entrada$edad_retiro - res73_orig$entrada$edad_actual)
semanas_al_retiro_new <- semanas_slider + (anios_restantes_orig * 52)

res73_more_sem <- calculate_ley73_pension(
  sbc_promedio_diario = sbc_diario,
  semanas = semanas_al_retiro_new,
  edad = 65
)
cat(sprintf("  After semanas->2000: pension %s (incrementos=%d)\n",
  format_currency(res73_more_sem$pension_mensual), res73_more_sem$n_incrementos))

check("Ley73 more semanas -> higher or equal pension",
  unname(res73_more_sem$pension_mensual) >= unname(res73_orig$pension_base$pension_mensual))

# ============================================================
# TEST 3: result_cards rendering path
# ============================================================
cat("\n--- TEST 3: Result Cards Rendering Path ---\n")

ley97_fields <- c("regimen", "solo_sistema", "con_fondo", "con_acciones", "entrada", "fondo_aplica")
for (f in ley97_fields) {
  check(sprintf("Ley97 result has field: %s", f),
    f %in% names(res_original))
}

ley73_fields <- c("regimen", "pension_base", "fondo_aplica", "entrada")
for (f in ley73_fields) {
  check(sprintf("Ley73 result has field: %s", f),
    f %in% names(res73_orig))
}

check("Ley97 entrada has edad_retiro", "edad_retiro" %in% names(res_original$entrada))
check("Ley97 entrada has semanas_actuales", "semanas_actuales" %in% names(res_original$entrada))
check("Ley97 entrada has afore", "afore" %in% names(res_original$entrada))
check("Ley73 entrada has edad_retiro", "edad_retiro" %in% names(res73_orig$entrada))
check("Ley73 entrada has semanas_actuales", "semanas_actuales" %in% names(res73_orig$entrada))

# ============================================================
# SUMMARY
# ============================================================
cat(sprintf("\n===== RESULTS: %d PASS, %d FAIL =====\n", pass_count, fail_count))
if (fail_count > 0) quit(status = 1)
