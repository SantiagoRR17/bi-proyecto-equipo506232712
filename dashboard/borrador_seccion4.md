# Borrador de la sección 4 del informe (tablero)

> **Estado:** borrador. Las cifras salen de `consultas_tablero.sql` sobre un DW cargado con las reglas del ETL, **no** de Power BI. Antes de entregar, abrir el tablero y confirmar que cada cifra coincide; si difiere, manda el tablero (y se revisa la medida o la carga).

## 4.1 Indicadores

| Indicador | Fórmula (DAX o SQL) | Qué mide | Referencia | Pregunta |
|---|---|---|---|---|
| I1. Empresas vigentes | `Empresas vigentes` (DAX en `dashboard/medidas.dax`; SQL: Q01) = suma de `empresas_vigentes` del corte seleccionado (el más reciente por defecto) | Empresas vigentes de Bogotá (o de la localidad filtrada) en un corte | **Corte anterior** (`Empresas corte anterior`) y variación % | P0, P1, P4 |
| I2. Establecimientos vigentes | `Establecimientos vigentes` (DAX; SQL: Q02) | Establecimientos vigentes en un corte | **Corte anterior** y variación % (2023 no disponible en la fuente) | P0, P1 |
| I3. Alojamientos por localidad | `Alojamientos = COUNTROWS(fact_alojamiento)` (SQL: Q03, Q08) | Establecimientos de alojamiento inscritos en el RNT | **Promedio por localidad con alojamientos** (≈49,4), línea de promedio en el visual 3.1 | P0, P2 |
| I4. Promedio mensual de hurtos | `Promedio mensual hurtos = Hurtos registros / meses con datos` (DAX; SQL: Q04) | Registros de hurto por mes en el periodo seleccionado | **Promedio mensual histórico** (888,3 registros/mes, 2010 a jul-2026) | P0, P3, P4 |

## 4.2 Respuesta a las preguntas de negocio

| Pregunta | Página y visual | Tipo de gráfico y por qué | Respuesta encontrada (con cifra) |
|---|---|---|---|
| P0 | Pág. 1: KPI 1.1–1.3, tarjeta 1.4, columnas 1.5 y línea 1.6 | KPI (cifra + referencia), columnas por corte (cortes puntuales) y línea anual (serie continua) | Las empresas vigentes pasaron de 400.077 (sep-2023) a 450.376 (mar-2024, +12,6 %) y a 378.759 (jul-2025, −15,9 %); los establecimientos pasaron de 257.751 (mar-2024) a 221.444 (jul-2025, −14,1 %). El RNT registra 839 alojamientos en 17 de las 20 localidades (corte 22/10/2026). Los hurtos suman 176.776 registros de 2010 a julio de 2026: 17.071 en 2024, 14.281 en 2025 y 9.173 en enero–julio de 2026. Limitaciones: los cortes no son una serie continua y 2023 no tiene establecimientos |
| P1 | Pág. 2: barras 2.1, columnas agrupadas 2.2 y tabla 2.3 | Barras ordenadas (ranking entre 20 localidades); columnas por corte (evolución por localidad); tabla (variaciones exactas) | En el último corte (jul-2025) Suba lidera con 46.228 empresas, seguida de Usaquén (38.307) y Chapinero (36.815); en establecimientos lideran Suba (22.882) y Kennedy (22.805). Entre mar-2024 y jul-2025 las 19 localidades registradas bajan entre −11,4 % (Chapinero) y −22,2 % (San Cristóbal) en empresas. «Sin localidad» suma 19.987 empresas |
| P2 | Pág. 3: barras 3.1 con promedio, barras 3.2, tarjetas 3.3–3.4 | Barras horizontales para comparar categorías nominales; promedio como referencia | Teusaquillo concentra 209 alojamientos (24,9 %) y Chapinero 160 (19,1 %); Santa Fe tiene 86 (10,3 %). Ciudad Bolívar, San Cristóbal y Sumapaz no tienen registros. La subcategoría SUBCATRNT 9 reúne 668 de 839 (79,6 %); 7: 86; 8: 68; 6: 13; 11: 2; 10 y 12: 1 cada una (se muestran por código porque el diccionario no permite nombrarlas) |
| P3 | Pág. 4: líneas 4.1, columnas apiladas 4.2, barras 4.3–4.5 | Línea para la evolución mensual; apiladas para total y composición por tipo; barras para comparar categorías | Hurtos a entidades comerciales cayeron de 18.690 (2019, año con más registros) a 11.123 (2021) y el de residencias aparece desde 2024 (6.095 en 2024; 6.073 en 2025). Por arma o medio: 76,9 % sin empleo de armas (135.970) y 8,3 % arma de fuego (14.650). El género está vacío en 90,8 % de los registros (160.540); por eso no se desagrega por género. El salto de 4.372 (2016) a 16.730 (2017) no se interpreta como cambio real |
| P4 | Pág. 5: líneas con índice 5.1 y tabla 5.2 | Índice base 2023 = 100 para poner en la misma escala series con unidades y periodicidad distintas; tabla para ver los tres procesos por localidad | Con base 2023 = 100, las empresas vigentes fueron 112,6 (2024) y 94,7 (2025) y los hurtos 146,4 (2024) y 122,4 (2025): ambos suben en 2024 y bajan en 2025, sin que esto implique causalidad. El alojamiento tiene un solo corte y no puede compararse en el tiempo; por localidad, Teusaquillo tiene 209 alojamientos con 12.979 empresas, mientras Suba tiene 46.228 empresas y 16 alojamientos |

## 4.3 Capturas del tablero

Una captura legible por página (5), las mismas que van en `dashboard/`.

## 4.4 Filtros

| Segmentador | Campo | Páginas donde actúa |
|---|---|---|
| Año | `dim_tiempo[anio]` | 1 a 5 (sincronizado; en la 3 solo 2026 devuelve datos) |
| Localidad | `dim_localidad[nombre_localidad]` | 1 a 5 (sincronizado) |
| Tipo de hurto | `dim_tipo_hurto[descripcion_tipo]` | 4 |
| Subcategoría RNT | `dim_tipo_alojamiento[cod_subcategoria]` | 3 |

## Limitaciones a declarar (no omitir)

- La columna LOCALIDAD de los hurtos fue asignada por el equipo con autorización del docente (reparto parejo, dato simulado): ninguna cifra de hurtos por localidad describe la realidad.
- Los tres cortes de dinámica empresarial no forman una serie continua ni son equidistantes.
