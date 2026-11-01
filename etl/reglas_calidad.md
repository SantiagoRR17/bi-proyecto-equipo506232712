# Correspondencia: problemas de calidad (Entrega 1, tabla 2.2) ↔ pasos de PDI

Los 15 problemas de la tabla 2.2 tienen un paso con nombre `P01…P15`. Los pasos `C-…` son controles adicionales
(llaves nulas, duplicados de llave, etc.) que no están en la tabla. Los conteos de reglas hechas en JavaScript salen
en el **log de PDI** al terminar cada transformación con el formato `nombre del paso | contador: n`; los de reglas
con filtro salen en **Step Metrics** (líneas escritas del paso `Rechazados …` / `Descartados …`).
Los valores «Esperado» se calcularon directamente de los archivos fuente (Python), así que sirven para verificar la ejecución real.

| # | Fuente · campo | Problema (Entrega 1) | Transformación · paso PDI | Cómo se mide | Esperado | Tratamiento |
|---|---|---|---|---|---|---|
| P01 | F1 · LOCALIDAD | Código sin cero a la izquierda («3» vs «03») | `t_fact_alojamiento` · `P01-F1 Completar LOCALIDAD a 2 digitos (3 -> 03)` y `P01-F1 Homologar LOCALIDAD con tabla de equivalencia` | log: `c_sin_cero_izquierda` | **438** de 839 | Se completa a 2 dígitos y se relaciona con `dim_localidad` |
| P02 | F1 · geometría / LATITUD, LONGITUD | Dos sistemas de coordenadas (EPSG:3857 y grados) | `t_fact_alojamiento` · `P02-F1 Excluir geometria (EPSG:3857) y LATITUD/LONGITUD; solo se usa LOCALIDAD` | Step Metrics (líneas escritas) | **839** | Decisión del equipo: el proyecto solo usa la localidad del alojamiento; no se cargan coordenadas, así que no hace falta reproyectar |
| P03 | F1 · SUBCATRNT | Códigos numéricos; el diccionario usa letras A–Z | `t_dim_tipo_alojamiento` · `P03-F1 Conservar codigo numerico SUBCATRNT (sin etiqueta A-Z)` | log: `c_codigo_numerico_sin_etiqueta` | **839** filas leídas (7 códigos distintos: 6–12) | Se conserva el código; `etiqueta` queda NULL (no se asigna sin certeza) |
| P04 | F2 · DEPARTAMENTO, MUNICIPIO, CODIGO DANE | Solo identifican a Bogotá, no la localidad | `t_fact_hurtos` · `P04-F2 Filtrar solo Bogota D.C. (DEPARTAMENTO = BOGOTA)` y `P04-F2 Verificar MUNICIPIO y CODIGO DANE de Bogota` | Step Metrics `Descartados F2 fuera de Bogota`; log `c_municipio_dane_incoherente` | **476.608** descartadas; **176.776** pasan; 0 incoherentes | Se filtra Bogotá; la localidad viene de P09 |
| P05 | F2 · FECHA HECHO | Texto dd/mm/aaaa | `t_fact_hurtos` · `P05-F2 Convertir FECHA HECHO (dd/mm/aaaa) a sk_tiempo` | log: `c_fecha_invalida` | 0 (rango 01/01/2010–31/07/2026) | Se convierte a `sk_tiempo` AAAAMMDD |
| P06 | F2 · CANTIDAD | Texto numérico (vale 1 en todas las filas) | `t_fact_hurtos` · `P06-F2 Validar CANTIDAD entera mayor que 0` | log: `c_cantidad_invalida` | 0 · SUM = **176.776** | Entero > 0; se conserva `cantidad_reportada` (filas ≠ suma) |
| P07 | F2 · GENERO, GRUPO ETARIO | Vacíos (90,8 % y 8,4 %) | `t_fact_hurtos` · `P07-F2 Vacios de genero, grupo etario y arma -> SIN DATO` | log: `c_genero_vacio`, `c_grupo_vacio`, `c_arma_vacio` | **160.540** · **14.811** · 0 | Etiqueta `SIN DATO`; no se imputan categorías |
| P08 | F2 · TIPO DE HURTO, ARMAS MEDIOS | Solo 2 tipos; ARMAS incluye NO REPORTADO | `t_fact_hurtos` / `t_dim_tipo_hurto` · `P08-F2 Tipificar tipo de hurto (articulo + descripcion)` | log: `c_tipo_vacio`, `c_tipo_sin_articulo`; `dim_tipo_hurto` = 2 filas | 0 · 0 · **2** tipos | Se separa artículo y descripción; NO REPORTADO se conserva como categoría |
| P09 | F2 · LOCALIDAD | Columna añadida; nombres con tildes y «La Candelaria» | `t_fact_hurtos` · `P09-F2 Normalizar LOCALIDAD…`, `P09-F2 Homologar LOCALIDAD con tabla de equivalencia`, `P09-F2 Contar LOCALIDAD sin equivalencia…` | log: `c_localidad_vacia`, `c_sin_equivalencia` | 0 · 0 (≈8.838–8.839 por localidad) | Tabla `equivalencia_localidad.csv` → `cod_localidad` |
| P10 | F2 · Duplicados | Sin identificador; filas que repiten los 9 campos | `t_fact_hurtos` · `P10-F2 Detectar repeticiones de los 9 campos originales (solo conteo)` (rama paralela) | Step Metrics: líneas escritas de `P10-F2 Duplicados potenciales (solo conteo; se conservan en el DW)` | **144.063** de 176.776 | No se marcan ni se eliminan: las 176.776 filas se cargan. Solo se cuenta y se declara como limitación |
| P11 | F3 · LOCCODIGO / LOCNOMBRE | Código y nombre inconsistentes entre archivos; código 21 «Sin Localidad» | `t_fact_dinamica_empresarial` · `P11-F3 Unificar identificador de localidad (codigo o nombre)` y `P11-F3 Homologar con tabla de equivalencia` | log: `c_identificado_por_nombre`, `c_sin_localidad_21` | **20** (2025) · **2** (2023 y 2024) | Se agrupa por LOCNOMBRE (no por LOCCODIGO, que en 2025 es un índice erróneo) y se homologa; 21 y «Sin Localidad» → miembro -1 |
| P12 | F3 · EstablecimientosVigentes 2023 | Nulos (capa vacía) | `t_fact_dinamica_empresarial` · `P12-F3 Conservar NULL de establecimientos (no imputar)` | log: `c_establecimientos_nulos` | **20** (cierre 2023-09; 19 en el resumen + «Sin Localidad») | Se conserva NULL |
| P13 | F3 · LOCNOMBRE / Periodo | Grafía distinta y un corte por año | `t_fact_dinamica_empresarial` · `P13-F3 {año} detalle agregado por localidad y corte (Periodo/Mes)` y contador de `P11` | log: `c_grafia_distinta`; 3 valores de `sk_tiempo` | **20** nombres con grafía distinta (2025); cortes 20230901, 20240301, 20250701 | El corte sale de Periodo/Mes del propio archivo |
| P14 | F4 · LocNombre | Mayúsculas sin tildes ≠ catálogo | `t_dim_localidad` · `P14-F4 Buscar nombre en tabla de equivalencia` y `P14-F4 Validar nombre contra tabla de equivalencia` | Step Metrics `Rechazados F4 nombre sin equivalencia` | **0** rechazados de 20 | Cada nombre de F4 debe resolver al mismo código por la tabla |
| P15 | F4 · sistema de referencia / diccionario | EPSG:4686 y sin diccionario | `t_dim_localidad` · `P15-F4 Excluir geometria (EPSG:4686) y conservar solo atributos` | Step Metrics (líneas escritas) | **20** | Solo atributos; diccionario en Anexo A.4 |

## Pasos de control (no están en la tabla 2.2)

`C-F1-01…06` (subcategoría nula, RNT nulo/no numérico/duplicado), `C-F2-01` (fecha, cantidad o tipo inválidos), `C-F2-04/05` (valores distintos para dimensiones), `C-F3-01` (localidad sin empresas), `C-F4-01…04` (código nulo, CHAR(2) inválido, duplicado). Esperado en los datos actuales: **0 rechazos** en todos.

## Notas

- Los contadores de `t_dim_tipo_hurto` y `t_dim_caracteristica_hurto` repiten los de F2 porque reutilizan el mismo frente; para el informe usar los de `t_fact_hurtos`.
- F3: las sumas de `EmpresasVigentes` ignoran valores nulos del detalle (4.267, 273 y 1.256 filas nulas en 2023, 2024 y 2025). Es un supuesto a declarar.
