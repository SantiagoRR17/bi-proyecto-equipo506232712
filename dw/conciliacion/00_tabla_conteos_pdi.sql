-- =============================================================================
-- 00_tabla_conteos_pdi.sql
-- Tabla donde el equipo registra los conteos que muestra PDI (Step Metrics / log) tras ejecutar el job.
-- Se usa en la sección 4 de 02_conciliar.sql. Es opcional: sin filas, esa sección queda vacía.
-- Ejecutar una vez (después de 01_crear_modelo_dw.sql).
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS stg;
CREATE TABLE IF NOT EXISTS stg.conciliacion_pdi (
    fuente   VARCHAR(10) NOT NULL,
    concepto VARCHAR(80) NOT NULL,      -- mismo nombre que en stg.conciliacion_fuente
    clave    VARCHAR(20) NOT NULL DEFAULT '',
    valor    NUMERIC,
    paso_pdi VARCHAR(120)               -- nombre del paso o contador del que sale el valor
);
-- Ejemplo (reemplazar por los valores reales de su ejecución):
-- INSERT INTO stg.conciliacion_pdi (fuente, concepto, valor, paso_pdi) VALUES
--   ('F2', 'info_leidas',                   653384, 'F2 Hurtos (CSV) - líneas leídas'),
--   ('F2', 'info_descartadas_fuera_bogota', 476608, 'Descartados F2 fuera de Bogota - líneas escritas'),
--   ('F2', 'cmp_filas_total',               176776, 'Carga fact_hurtos - líneas escritas'),
--   ('F1', 'info_localidad_sin_cero_izquierda', 438, 'P01-F1 ... | c_sin_cero_izquierda (log)');
