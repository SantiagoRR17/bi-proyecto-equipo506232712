-- =============================================================================
-- 02_conciliar.sql  —  Conciliación de filas y cantidades: fuente vs. almacén de datos
--
-- Orden: 01_valores_fuente.sql (generado por generar_valores_fuente.py) -> 00_tabla_conteos_pdi.sql -> este archivo.
-- Solo lectura sobre dw.*. Cada comparación devuelve estado OK o DIFERENCIA.
--   Sección 1: leídos = cargados + descartados (por fuente)
--   Sección 2: cantidades y distribuciones (suma de CANTIDAD, empresas por corte, filas por localidad, año, etc.)
--   Sección 3: resumen (número de comprobaciones y diferencias)
--   Sección 4: conteos de PDI (stg.conciliacion_pdi) frente a lo esperado
--   Sección 5: controles de integridad e informativos (llaves -1, huérfanos)
-- =============================================================================

-- Valores que realmente quedaron en el DW, con los mismos nombres de concepto que stg.conciliacion_fuente
DROP TABLE IF EXISTS dw_vals;
CREATE TEMP TABLE dw_vals AS
SELECT 'F1'::text AS fuente, 'cmp_filas_total'::text AS concepto, ''::text AS clave, COUNT(*)::numeric AS valor FROM dw.fact_alojamiento
UNION ALL SELECT 'F1', 'cmp_filas_localidad', l.cod_localidad, COUNT(*) FROM dw.fact_alojamiento f JOIN dw.dim_localidad l USING (sk_localidad)
          WHERE l.sk_localidad <> -1 GROUP BY l.cod_localidad
UNION ALL SELECT 'F1', 'cmp_filas_subcategoria', t.cod_subcategoria, COUNT(*) FROM dw.fact_alojamiento f JOIN dw.dim_tipo_alojamiento t USING (sk_tipo_alojamiento)
          WHERE t.sk_tipo_alojamiento <> -1 GROUP BY t.cod_subcategoria
UNION ALL SELECT 'F1', 'cmp_filas_con_localidad_valida', '', COUNT(*) FILTER (WHERE sk_localidad <> -1) FROM dw.fact_alojamiento
UNION ALL SELECT 'F2', 'cmp_filas_total', '', COUNT(*) FROM dw.fact_hurtos
UNION ALL SELECT 'F2', 'cmp_suma_cantidad', '', SUM(cantidad_reportada) FROM dw.fact_hurtos
UNION ALL SELECT 'F2', 'cmp_filas_anio', t.anio::text, COUNT(*) FROM dw.fact_hurtos f JOIN dw.dim_tiempo t USING (sk_tiempo) GROUP BY t.anio
UNION ALL SELECT 'F2', 'cmp_filas_localidad', l.cod_localidad, COUNT(*) FROM dw.fact_hurtos f JOIN dw.dim_localidad l USING (sk_localidad)
          WHERE l.sk_localidad <> -1 GROUP BY l.cod_localidad
UNION ALL SELECT 'F2', 'cmp_filas_genero_sin_dato', '', COUNT(*) FROM dw.fact_hurtos f JOIN dw.dim_caracteristica_hurto c USING (sk_caracteristica) WHERE c.genero = 'SIN DATO'
UNION ALL SELECT 'F2', 'cmp_filas_grupo_sin_dato', '', COUNT(*) FROM dw.fact_hurtos f JOIN dw.dim_caracteristica_hurto c USING (sk_caracteristica) WHERE c.grupo_etario = 'SIN DATO'
UNION ALL SELECT 'F3', 'cmp_filas_total', '', COUNT(*) FROM dw.fact_dinamica_empresarial
UNION ALL SELECT 'F3', 'cmp_filas_corte', sk_tiempo::text, COUNT(*) FROM dw.fact_dinamica_empresarial GROUP BY sk_tiempo
UNION ALL SELECT 'F3', 'cmp_empresas_corte', sk_tiempo::text, SUM(empresas_vigentes) FROM dw.fact_dinamica_empresarial GROUP BY sk_tiempo
UNION ALL SELECT 'F3', 'cmp_establecimientos_corte', sk_tiempo::text, SUM(establecimientos_vigentes) FROM dw.fact_dinamica_empresarial GROUP BY sk_tiempo
UNION ALL SELECT 'F3', 'cmp_establecimientos_nulos_corte', sk_tiempo::text, COUNT(*) FILTER (WHERE establecimientos_vigentes IS NULL) FROM dw.fact_dinamica_empresarial GROUP BY sk_tiempo
UNION ALL SELECT 'F4', 'cmp_dim_localidad', '', COUNT(*) FROM dw.dim_localidad WHERE sk_localidad <> -1
UNION ALL SELECT 'DIM', 'cmp_dim_tipo_alojamiento', '', COUNT(*) FROM dw.dim_tipo_alojamiento WHERE sk_tipo_alojamiento <> -1
UNION ALL SELECT 'DIM', 'cmp_dim_tipo_hurto', '', COUNT(*) FROM dw.dim_tipo_hurto WHERE sk_tipo_hurto <> -1
UNION ALL SELECT 'DIM', 'cmp_dim_caracteristica_hurto', '', COUNT(*) FROM dw.dim_caracteristica_hurto WHERE sk_caracteristica <> -1
UNION ALL SELECT 'DIM', 'cmp_dim_tiempo', '', COUNT(*) FROM dw.dim_tiempo;


-- ---------------------------------------------------------------------------
-- 1) LEÍDOS = CARGADOS + DESCARTADOS (F1 y F2: una fila de la fuente = una fila del hecho)
-- ---------------------------------------------------------------------------
WITH f AS (SELECT fuente, concepto, clave, valor FROM stg.conciliacion_fuente),
flujo AS (
  SELECT x.fuente,
         (SELECT valor FROM f WHERE fuente = x.fuente AND concepto = 'info_leidas')                                  AS leidas,
         COALESCE((SELECT SUM(valor) FROM f WHERE fuente = x.fuente AND concepto LIKE 'info\_descartadas\_%'), 0)     AS descartadas,
         (SELECT valor FROM dw_vals WHERE fuente = x.fuente AND concepto = 'cmp_filas_total')                        AS cargadas_dw
    FROM (VALUES ('F1'), ('F2')) AS x(fuente)
)
SELECT fuente, leidas, descartadas, leidas - descartadas AS esperadas_cargadas, cargadas_dw,
       cargadas_dw - (leidas - descartadas) AS diferencia,
       CASE WHEN cargadas_dw = leidas - descartadas THEN 'OK' ELSE 'DIFERENCIA' END AS estado
  FROM flujo ORDER BY fuente;

-- F3 cambia de grano: filas de detalle (Empresas/Establecimientos) -> una fila por localidad y corte
SELECT 'F3' AS fuente,
       (SELECT SUM(valor) FROM stg.conciliacion_fuente WHERE concepto = 'info_leidas_detalle_empresas')         AS filas_detalle_empresas,
       (SELECT SUM(valor) FROM stg.conciliacion_fuente WHERE concepto = 'info_leidas_detalle_establecimientos') AS filas_detalle_establecimientos,
       (SELECT valor FROM stg.conciliacion_fuente WHERE fuente = 'F3' AND concepto = 'cmp_filas_total')         AS filas_agregadas_esperadas,
       (SELECT valor FROM dw_vals WHERE fuente = 'F3' AND concepto = 'cmp_filas_total')                          AS filas_cargadas_dw;

-- ---------------------------------------------------------------------------
-- 2) CANTIDADES Y DISTRIBUCIONES: esperado (fuente) frente a lo cargado (DW)
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS comparacion;
CREATE TEMP TABLE comparacion AS
SELECT COALESCE(s.fuente, d.fuente) AS fuente, COALESCE(s.concepto, d.concepto) AS concepto,
       COALESCE(s.clave, d.clave, '') AS clave, s.valor AS esperado_fuente, d.valor AS cargado_dw,
       CASE WHEN s.valor IS NOT DISTINCT FROM d.valor THEN 'OK' ELSE 'DIFERENCIA' END AS estado
  FROM (SELECT * FROM stg.conciliacion_fuente WHERE concepto LIKE 'cmp\_%') s
  FULL JOIN (SELECT fuente, concepto, COALESCE(clave, '') AS clave, valor FROM dw_vals) d
    ON d.fuente = s.fuente AND d.concepto = s.concepto AND d.clave = s.clave;

-- valores que el DW debe tener pero que NULL en ambos lados (p. ej. suma de establecimientos 2023) cuentan como OK
SELECT fuente, concepto, clave, esperado_fuente, cargado_dw, estado
  FROM comparacion ORDER BY (estado = 'OK'), fuente, concepto, clave;

-- ---------------------------------------------------------------------------
-- 3) RESUMEN
-- ---------------------------------------------------------------------------
SELECT COUNT(*) AS comprobaciones, COUNT(*) FILTER (WHERE estado = 'OK') AS ok,
       COUNT(*) FILTER (WHERE estado <> 'OK') AS diferencias,
       CASE WHEN COUNT(*) FILTER (WHERE estado <> 'OK') = 0 THEN 'CONCILIACION OK' ELSE 'REVISAR DIFERENCIAS' END AS resultado
  FROM comparacion;

-- ---------------------------------------------------------------------------
-- 4) CONTEOS REPORTADOS POR PDI vs. ESPERADO (solo filas registradas en stg.conciliacion_pdi)
-- ---------------------------------------------------------------------------
SELECT p.fuente, p.concepto, p.clave, s.valor AS esperado_fuente, p.valor AS reportado_pdi, p.paso_pdi,
       CASE WHEN s.valor IS NOT DISTINCT FROM p.valor THEN 'OK' ELSE 'DIFERENCIA' END AS estado
  FROM stg.conciliacion_pdi p
  LEFT JOIN stg.conciliacion_fuente s ON s.fuente = p.fuente AND s.concepto = p.concepto AND s.clave = p.clave
 ORDER BY (s.valor IS NOT DISTINCT FROM p.valor), p.fuente, p.concepto, p.clave;

-- ---------------------------------------------------------------------------
-- 5) INTEGRIDAD E INFORMATIVOS (no son fallas por sí mismos; explicarlos en el informe)
-- ---------------------------------------------------------------------------
SELECT 'fact_hurtos con localidad -1 (sin equivalencia)'           AS control, COUNT(*) AS filas FROM dw.fact_hurtos WHERE sk_localidad = -1
UNION ALL SELECT 'fact_hurtos con tipo de hurto -1',                COUNT(*) FROM dw.fact_hurtos WHERE sk_tipo_hurto = -1
UNION ALL SELECT 'fact_hurtos con característica -1',               COUNT(*) FROM dw.fact_hurtos WHERE sk_caracteristica = -1
UNION ALL SELECT 'fact_alojamiento con localidad -1',               COUNT(*) FROM dw.fact_alojamiento WHERE sk_localidad = -1
UNION ALL SELECT 'fact_alojamiento con tipo -1',                    COUNT(*) FROM dw.fact_alojamiento WHERE sk_tipo_alojamiento = -1
UNION ALL SELECT 'fact_dinamica con localidad -1 (código 21 Sin Localidad)', COUNT(*) FROM dw.fact_dinamica_empresarial WHERE sk_localidad = -1
UNION ALL SELECT 'fact_dinamica con establecimientos NULL (2023 sin dato)',   COUNT(*) FROM dw.fact_dinamica_empresarial WHERE establecimientos_vigentes IS NULL
UNION ALL SELECT 'localidades sin ningún hurto',                    COUNT(*) FROM dw.dim_localidad l WHERE sk_localidad <> -1 AND NOT EXISTS (SELECT 1 FROM dw.fact_hurtos f WHERE f.sk_localidad = l.sk_localidad)
UNION ALL SELECT 'localidades sin ningún alojamiento',              COUNT(*) FROM dw.dim_localidad l WHERE sk_localidad <> -1 AND NOT EXISTS (SELECT 1 FROM dw.fact_alojamiento f WHERE f.sk_localidad = l.sk_localidad)
UNION ALL SELECT 'localidades sin dinámica empresarial',            COUNT(*) FROM dw.dim_localidad l WHERE sk_localidad <> -1 AND NOT EXISTS (SELECT 1 FROM dw.fact_dinamica_empresarial f WHERE f.sk_localidad = l.sk_localidad);
