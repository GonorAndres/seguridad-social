# tests/validate_results_responsiveness.R
# Validates that different inputs produce different intermediate results
# and that new fields (pension_calculada, pension_minima,
# saldo_minimo_para_superar_garantia) are propagated through the chain.

cat("=== Results Responsiveness Validation ===\n\n")

# Source global.R to load all functions and constants
source("global.R")

pass_count <- 0
fail_count <- 0

assert <- function(condition, msg) {
  if (condition) {
    cat("  PASS:", msg, "\n")
    pass_count <<- pass_count + 1
  } else {
    cat("  FAIL:", msg, "\n")
    fail_count <<- fail_count + 1
  }
}

# --- Test 1: Different salaries produce different pension_calculada and saldo ---
cat("Test 1: Salary $20k vs $30k vs $50k\n")

res_20k <- calculate_pension_with_fondo(
  saldo_actual = 200000, salario_mensual = 20000,
  edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 0
)

res_30k <- calculate_pension_with_fondo(
  saldo_actual = 200000, salario_mensual = 30000,
  edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 0
)

res_50k <- calculate_pension_with_fondo(
  saldo_actual = 200000, salario_mensual = 50000,
  edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 0
)

assert(
  res_20k$solo_sistema$pension_calculada != res_30k$solo_sistema$pension_calculada,
  "pension_calculada differs between $20k and $30k salary"
)
assert(
  res_30k$solo_sistema$pension_calculada != res_50k$solo_sistema$pension_calculada,
  "pension_calculada differs between $30k and $50k salary"
)
assert(
  res_20k$solo_sistema$saldo_proyectado != res_30k$solo_sistema$saldo_proyectado,
  "saldo_proyectado differs between $20k and $30k salary"
)
assert(
  res_30k$solo_sistema$saldo_proyectado < res_50k$solo_sistema$saldo_proyectado,
  "saldo_proyectado higher for $50k than $30k"
)

# --- Test 2: aplico_minimo is TRUE for low salary + shorter horizon ---
cat("\nTest 2: aplico_minimo TRUE for $15k salary, age 45->65\n")
res_low <- calculate_pension_with_fondo(
  saldo_actual = 50000, salario_mensual = 15000,
  edad_actual = 45, edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 0
)
assert(
  isTRUE(res_low$solo_sistema$aplico_minimo),
  "aplico_minimo is TRUE for $15k salary (45->65)"
)

# --- Test 3: aplico_minimo is FALSE for $50k salary ---
cat("\nTest 3: aplico_minimo FALSE for $50k\n")
assert(
  !isTRUE(res_50k$solo_sistema$aplico_minimo),
  "aplico_minimo is FALSE for $50k salary"
)

# --- Test 4: Fondo eligibility flips at age 65 ---
cat("\nTest 4: Fondo eligibility at age 60 vs 65\n")
res_age60 <- calculate_pension_with_fondo(
  saldo_actual = 200000, salario_mensual = 15000,
  edad_actual = 35, edad_retiro = 60, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 0
)
res_age65 <- calculate_pension_with_fondo(
  saldo_actual = 200000, salario_mensual = 15000,
  edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 0
)

assert(
  !res_age60$con_fondo$elegible,
  "Fondo NOT eligible at age 60"
)
assert(
  res_age65$con_fondo$elegible,
  "Fondo IS eligible at age 65"
)

# --- Test 5: Salary $15k at age 65 -> fondo eligible ---
cat("\nTest 5: Salary $15k at age 65 -> fondo eligible\n")
assert(
  res_age65$fondo_bienestar$elegible,
  "Salary $15k at 65 is eligible for Fondo Bienestar"
)

# --- Test 6: Voluntary $0 vs $2000 -> saldo differs ---
cat("\nTest 6: Voluntary contributions change saldo\n")
res_vol0 <- calculate_pension_with_fondo(
  saldo_actual = 200000, salario_mensual = 25000,
  edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 0
)
res_vol2k <- calculate_pension_with_fondo(
  saldo_actual = 200000, salario_mensual = 25000,
  edad_actual = 35, edad_retiro = 65, semanas_actuales = 500,
  genero = "M", aportacion_voluntaria = 2000
)
assert(
  res_vol2k$con_acciones$saldo_proyectado > res_vol0$con_acciones$saldo_proyectado,
  "saldo_proyectado higher with $2000 voluntary vs $0"
)

# --- Test 7: All new fields are non-NULL ---
cat("\nTest 7: New fields are non-NULL in all scenarios\n")

check_fields <- function(res, label) {
  assert(!is.null(res$solo_sistema$pension_calculada),
    paste0(label, ": solo_sistema$pension_calculada is not NULL"))
  assert(!is.null(res$solo_sistema$pension_minima),
    paste0(label, ": solo_sistema$pension_minima is not NULL"))
  assert(!is.null(res$solo_sistema$saldo_minimo_para_superar_garantia),
    paste0(label, ": solo_sistema$saldo_minimo_para_superar_garantia is not NULL"))
  assert(!is.null(res$con_acciones$pension_calculada),
    paste0(label, ": con_acciones$pension_calculada is not NULL"))
  assert(!is.null(res$con_acciones$pension_minima),
    paste0(label, ": con_acciones$pension_minima is not NULL"))
  assert(!is.null(res$con_acciones$saldo_minimo_para_superar_garantia),
    paste0(label, ": con_acciones$saldo_minimo_para_superar_garantia is not NULL"))
}

check_fields(res_20k, "$20k")
check_fields(res_30k, "$30k")
check_fields(res_50k, "$50k")
check_fields(res_age65, "$15k@65")

cat("\n=== Results ===\n")
cat("Passed:", pass_count, "\n")
cat("Failed:", fail_count, "\n")

if (fail_count > 0) {
  cat("\n*** SOME TESTS FAILED ***\n")
  quit(status = 1)
} else {
  cat("\nAll tests passed.\n")
}
