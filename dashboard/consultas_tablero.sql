-- =============================================================================
-- consultas_tablero.sql — Verificación de las cifras del tablero (equivalente SQL de las medidas DAX)
-- Ejecutar sobre observatorio_bi DESPUÉS de cargar el DW. Cada consulta indica qué visual/indicador verifica.
-- Sirven para (a) comprobar que Power BI muestra lo mismo y (b) tomar las cifras de la tabla 4.2 del informe.
-- =============================================================================

-- Q01 [Pág. 1 · KPI Empresas] Empresas vigentes por corte, referencia = corte anterior
SELECT t.fecha AS corte, SUM(f.empresas_vigentes) AS empresas_vigentes,
       LAG(SUM(f.empresas_vigentes)) OVER (ORDER BY t.fecha) AS corte_anterior,
       ROUND(100.0 * (SUM(f.empresas_vigentes) - LAG(SUM(f.empresas_vigentes)) OVER (ORDER BY t.fecha))
             / NULLIF(LAG(SUM(f.empresas_vigentes)) OVER (ORDER BY t.fecha), 0), 1) AS variacion_pct
  FROM dw.fact_dinamica_empresarial f JOIN dw.dim_tiempo t USING (sk_tiempo)
 GROUP BY t.fecha ORDER BY t.fecha;

-- Q02 [Pág. 1 · KPI Establecimientos] Establecimientos vigentes por corte (2023 no disponible)
SELECT t.fecha AS corte, SUM(f.establecimientos_vigentes) AS establecimientos_vigentes,
       LAG(SUM(f.establecimientos_vigentes)) OVER (ORDER BY t.fecha) AS corte_anterior,
       ROUND(100.0 * (SUM(f.establecimientos_vigentes) - LAG(SUM(f.establecimientos_vigentes)) OVER (ORDER BY t.fecha))
             / NULLIF(LAG(SUM(f.establecimientos_vigentes)) OVER (ORDER BY t.fecha), 0), 1) AS variacion_pct
  FROM dw.fact_dinamica_empresarial f JOIN dw.dim_tiempo t USING (sk_tiempo)
 GROUP BY t.fecha ORDER BY t.fecha;

-- Q03 [Pág. 1 · KPI Alojamientos] Total y promedio por localidad con alojamientos (referencia = promedio)
SELECT COUNT(*) AS alojamientos,
       COUNT(DISTINCT sk_localidad) AS localidades_con_alojamientos,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT sk_localidad), 1) AS promedio_por_localidad
  FROM dw.fact_alojamiento;

-- Q04 [Pág. 1 · KPI Hurtos] Promedio mensual de hurtos, total y en el último año, frente al promedio histórico
WITH m AS (SELECT t.anio, t.numero_mes, COUNT(*) AS hurtos
             FROM dw.fact_hurtos f JOIN dw.dim_tiempo t USING (sk_tiempo) GROUP BY t.anio, t.numero_mes)
SELECT ROUND(AVG(hurtos), 1) AS promedio_mensual_historico,
       ROUND(AVG(hurtos) FILTER (WHERE anio = 2026), 1) AS promedio_mensual_2026,
       ROUND(AVG(hurtos) FILTER (WHERE anio = 2025), 1) AS promedio_mensual_2025,
       ROUND(AVG(hurtos) FILTER (WHERE anio >= 2017), 1) AS promedio_mensual_desde_2017,
       COUNT(*) AS meses_con_datos
  FROM m;

-- Q05 [Pág. 1 · Línea] Hurtos por año (registros y cantidad). 2026 es parcial (enero a julio)
SELECT t.anio, COUNT(*) AS registros, SUM(f.cantidad_reportada) AS cantidad_reportada, COUNT(DISTINCT t.numero_mes) AS meses_con_datos
  FROM dw.fact_hurtos f JOIN dw.dim_tiempo t USING (sk_tiempo) GROUP BY t.anio ORDER BY t.anio;

-- Q06 [Pág. 2 · Barras] Empresas vigentes por localidad, último corte, con variación frente al corte anterior
WITH e AS (SELECT l.nombre_localidad, t.fecha, f.empresas_vigentes, f.establecimientos_vigentes,
                  LAG(f.empresas_vigentes) OVER w AS emp_ant, LAG(f.establecimientos_vigentes) OVER w AS est_ant
             FROM dw.fact_dinamica_empresarial f JOIN dw.dim_localidad l USING (sk_localidad) JOIN dw.dim_tiempo t USING (sk_tiempo)
             WINDOW w AS (PARTITION BY f.sk_localidad ORDER BY f.sk_tiempo))
SELECT nombre_localidad, empresas_vigentes, establecimientos_vigentes,
       ROUND(100.0 * (empresas_vigentes - emp_ant) / NULLIF(emp_ant, 0), 1) AS var_empresas_pct,
       ROUND(100.0 * (establecimientos_vigentes - est_ant) / NULLIF(est_ant, 0), 1) AS var_estab_pct
  FROM e WHERE fecha = (SELECT MAX(fecha) FROM dw.dim_tiempo t JOIN dw.fact_dinamica_empresarial f USING (sk_tiempo))
 ORDER BY empresas_vigentes DESC;

-- Q07 [Pág. 2 · Columnas por corte] Empresas por localidad y corte (top 5 del último corte)
SELECT l.nombre_localidad, t.fecha AS corte, f.empresas_vigentes
  FROM dw.fact_dinamica_empresarial f JOIN dw.dim_localidad l USING (sk_localidad) JOIN dw.dim_tiempo t USING (sk_tiempo)
 WHERE l.nombre_localidad IN (SELECT l2.nombre_localidad FROM dw.fact_dinamica_empresarial f2 JOIN dw.dim_localidad l2 USING (sk_localidad)
                               WHERE f2.sk_tiempo = (SELECT MAX(sk_tiempo) FROM dw.fact_dinamica_empresarial) ORDER BY f2.empresas_vigentes DESC LIMIT 5)
 ORDER BY l.nombre_localidad, t.fecha;

-- Q08 [Pág. 3 · Barras] Alojamientos por localidad y participación
SELECT l.nombre_localidad, COUNT(*) AS alojamientos, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS participacion_pct
  FROM dw.fact_alojamiento f JOIN dw.dim_localidad l USING (sk_localidad) GROUP BY l.nombre_localidad ORDER BY alojamientos DESC;

-- Q09 [Pág. 3 · Barras] Alojamientos por subcategoría RNT (código original SUBCATRNT)
SELECT t.cod_subcategoria AS subcategoria_rnt, COUNT(*) AS alojamientos, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS participacion_pct
  FROM dw.fact_alojamiento f JOIN dw.dim_tipo_alojamiento t USING (sk_tipo_alojamiento) GROUP BY t.cod_subcategoria ORDER BY alojamientos DESC;

-- Q10 [Pág. 3 · Localidades sin alojamientos] Para la nota de cobertura
SELECT l.nombre_localidad FROM dw.dim_localidad l
 WHERE l.sk_localidad <> -1 AND NOT EXISTS (SELECT 1 FROM dw.fact_alojamiento f WHERE f.sk_localidad = l.sk_localidad) ORDER BY 1;

-- Q11 [Pág. 4 · Columnas apiladas] Hurtos por año y tipo de hurto
SELECT t.anio, th.descripcion_tipo AS tipo_hurto, COUNT(*) AS registros
  FROM dw.fact_hurtos f JOIN dw.dim_tiempo t USING (sk_tiempo) JOIN dw.dim_tipo_hurto th USING (sk_tipo_hurto)
 GROUP BY t.anio, th.descripcion_tipo ORDER BY t.anio, 2;

-- Q12 [Pág. 4 · Barras] Hurtos por arma o medio
SELECT c.arma_medio, COUNT(*) AS registros, ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS participacion_pct
  FROM dw.fact_hurtos f JOIN dw.dim_caracteristica_hurto c USING (sk_caracteristica) GROUP BY c.arma_medio ORDER BY registros DESC;

-- Q13 [Pág. 4 · Barras] Hurtos por género y grupo etario (SIN DATO se muestra, no se imputa)
SELECT c.genero, c.grupo_etario, COUNT(*) AS registros
  FROM dw.fact_hurtos f JOIN dw.dim_caracteristica_hurto c USING (sk_caracteristica) GROUP BY c.genero, c.grupo_etario ORDER BY registros DESC LIMIT 12;

-- Q14 [Pág. 4 · Barras] Hurtos por localidad (LOCALIDAD asignada por el equipo: dato simulado)
SELECT l.nombre_localidad, COUNT(*) AS registros FROM dw.fact_hurtos f JOIN dw.dim_localidad l USING (sk_localidad)
 GROUP BY l.nombre_localidad ORDER BY registros DESC, 1;

-- Q15 [Pág. 4 · Línea mensual] Hurtos por mes (para la tendencia mensual)
SELECT t.anio, t.numero_mes, COUNT(*) AS registros FROM dw.fact_hurtos f JOIN dw.dim_tiempo t USING (sk_tiempo)
 GROUP BY t.anio, t.numero_mes ORDER BY 1, 2;

-- Q16 [Pág. 5 · Índice base 100] Empresas (cortes 2023, 2024, 2025) y hurtos (años completos) con base 2023 = 100
WITH e AS (SELECT t.anio, SUM(f.empresas_vigentes) AS valor FROM dw.fact_dinamica_empresarial f JOIN dw.dim_tiempo t USING (sk_tiempo) GROUP BY t.anio),
     h AS (SELECT t.anio, COUNT(*) AS valor FROM dw.fact_hurtos f JOIN dw.dim_tiempo t USING (sk_tiempo) WHERE t.anio BETWEEN 2023 AND 2025 GROUP BY t.anio)
SELECT e.anio, e.valor AS empresas, ROUND(100.0 * e.valor / FIRST_VALUE(e.valor) OVER (ORDER BY e.anio), 1) AS indice_empresas,
       h.valor AS hurtos, ROUND(100.0 * h.valor / FIRST_VALUE(h.valor) OVER (ORDER BY e.anio), 1) AS indice_hurtos
  FROM e JOIN h USING (anio) ORDER BY e.anio;

-- Q17 [Pág. 5 · Tabla comparativa por localidad] Empresas (último corte), alojamientos y hurtos (2025, último año completo)
SELECT l.nombre_localidad,
       (SELECT f.empresas_vigentes FROM dw.fact_dinamica_empresarial f WHERE f.sk_localidad = l.sk_localidad
         AND f.sk_tiempo = (SELECT MAX(sk_tiempo) FROM dw.fact_dinamica_empresarial)) AS empresas_ult_corte,
       (SELECT COUNT(*) FROM dw.fact_alojamiento a WHERE a.sk_localidad = l.sk_localidad) AS alojamientos,
       (SELECT COUNT(*) FROM dw.fact_hurtos h JOIN dw.dim_tiempo t USING (sk_tiempo) WHERE h.sk_localidad = l.sk_localidad AND t.anio = 2025) AS hurtos_2025
  FROM dw.dim_localidad l WHERE l.sk_localidad <> -1 ORDER BY empresas_ult_corte DESC NULLS LAST;
