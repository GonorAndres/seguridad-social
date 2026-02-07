# Simulador de Pension IMSS + Fondo Bienestar

Aplicacion interactiva en R Shiny que ayuda a trabajadores mexicanos a estimar su pension de retiro bajo el IMSS (Ley 73 y Ley 97), incluyendo el nuevo Fondo de Pensiones para el Bienestar (2024).

## Caracteristicas

- **Calculadora Ley 73**: Para trabajadores que comenzaron a cotizar antes de julio 1997
  - Usa la tabla del Articulo 167 de la Ley del Seguro Social
  - Calcula cuantia basica, incrementos anuales y factores de cesantia

- **Calculadora Ley 97**: Para trabajadores del sistema de AFOREs
  - Proyeccion de saldo de cuenta individual
  - Calculo de pension por retiro programado

- **Fondo de Pensiones para el Bienestar**: Evaluacion de elegibilidad y complemento
  - Verifica si cumples requisitos (edad, semanas, salario)
  - Calcula el complemento para llegar al 100% del salario

- **Analisis de sensibilidad**: Escenarios conservador, base y optimista

## Estructura del Proyecto

```
seguridad_social/
├── app.R                      # Aplicacion principal Shiny
├── global.R                   # Carga de paquetes y datos
├── R/
│   ├── calculations.R         # Formulas de pension (Ley 73 y 97)
│   ├── fondo_bienestar.R      # Logica del Fondo Bienestar
│   ├── data_tables.R          # Funciones de consulta de datos
│   └── ui_helpers.R           # Componentes de UI
├── www/
│   └── styles.css             # Estilos personalizados
├── data/
│   ├── articulo_167_tabla.csv # Tabla del Articulo 167
│   ├── uma_historico.csv      # Valores de UMA por ano
│   ├── salario_minimo.csv     # Salarios minimos historicos
│   └── afore_comisiones.csv   # Comisiones y rendimientos de AFOREs
└── tests/testthat/
    └── test_calculations.R    # Tests unitarios
```

## Instalacion

### Requisitos

- R >= 4.0
- Paquetes requeridos:
  - shiny
  - bslib
  - shinyjs
  - plotly
  - dplyr
  - scales

### Instalacion de dependencias

```r
install.packages(c("shiny", "bslib", "shinyjs", "plotly", "dplyr", "scales"))
```

### Ejecucion local

```r
# Desde el directorio del proyecto
shiny::runApp()

# O especificando la ruta
shiny::runApp("/ruta/a/seguridad_social")
```

## Uso

1. **Paso 1 - Datos Personales**: Ingresa fecha de nacimiento, genero y edad de retiro deseada
2. **Paso 2 - Datos Laborales**: Selecciona tu regimen (Ley 73 o 97), salario y semanas cotizadas
3. **Paso 3 - AFORE** (solo Ley 97): Selecciona tu AFORE, saldo actual y aportaciones voluntarias
4. **Paso 4 - Resultados**: Visualiza tu pension estimada con diferentes escenarios

## Fuentes de Datos

| Dato | Fuente | Actualizacion |
|------|--------|---------------|
| UMA | INEGI/DOF | Anual (febrero) |
| Salario Minimo | CONASAMI | Anual (enero) |
| Comisiones AFORE | CONSAR | Anual |
| Rendimientos AFORE | CONSAR | Mensual |

## Formulas Implementadas

### Ley 73 - Articulo 167

```
Pension = SBC_promedio × (Cuantia_basica + Incrementos) × Factor_edad × 30
```

Donde:
- Cuantia_basica: Segun tabla del Articulo 167 por grupo salarial
- Incrementos: Numero de anos adicionales × incremento anual
- Factor_edad: 75% (60 anos) hasta 100% (65+ anos)

### Ley 97 - Retiro Programado

```
Saldo_final = Saldo_actual × (1+r)^n + Sum(Aportaciones × (1+r)^t)
Pension_mensual = Saldo_final / (Esperanza_vida × Factor_ajuste) / 12
```

### Fondo Bienestar

```
Si salario <= umbral Y edad >= 65 Y semanas >= 1000:
    Complemento = max(0, Salario - Pension_AFORE)
Sino:
    Complemento = 0
```

## Disclaimer

Esta es una **estimacion educativa**. Las leyes y condiciones pueden cambiar. Consulta tu estado de cuenta oficial en:
- [IMSS Digital](https://serviciosdigitales.imss.gob.mx/)
- [CONSAR](https://www.consar.gob.mx/)

## Referencias

- [CIEP - Fondo de Pensiones para el Bienestar](https://ciep.mx/fondo-de-pensiones-para-el-bienestar/)
- [IMCO - Analisis del Fondo](https://imco.org.mx/fondo-de-pensiones-para-el-bienestar/)
- [Ley del Seguro Social 1973](https://www.imss.gob.mx/)
- [CONSAR - Calculadoras oficiales](https://www.consar.gob.mx/)

## Licencia

MIT License
