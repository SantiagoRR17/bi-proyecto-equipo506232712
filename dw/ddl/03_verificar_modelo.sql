-- =============================================================================
-- 03_verificar_modelo.sql
-- Consultas de verificación del modelo físico (solo lectura).
-- Sirven para llenar la tabla 1.2 del informe (tabla, tipo, PK, FK, registros).
-- =============================================================================

-- 1) Tablas del esquema dw con su llave primaria y número de llaves foráneas
SELECT c.relname                                         AS tabla,
       CASE WHEN c.relname LIKE 'fact\_%' THEN 'Hechos' ELSE 'Dimensión' END AS tipo,
       (SELECT string_agg(a.attname, ', ' ORDER BY k.ord)
          FROM pg_constraint p
          CROSS JOIN LATERAL unnest(p.conkey) WITH ORDINALITY AS k(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = p.conrelid AND a.attnum = k.attnum
         WHERE p.conrelid = c.oid AND p.contype = 'p')   AS llave_primaria,
       (SELECT count(*) FROM pg_constraint f
         WHERE f.conrelid = c.oid AND f.contype = 'f')   AS llaves_foraneas
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'dw' AND c.relkind = 'r'
 ORDER BY (c.relname LIKE 'fact\_%'), c.relname;

-- 2) Detalle de llaves foráneas: de qué hecho a qué dimensión
SELECT con.conrelid::regclass  AS tabla_hechos,
       a.attname               AS columna_fk,
       con.confrelid::regclass AS dimension_referenciada,
       con.conname             AS restriccion
  FROM pg_constraint con
  JOIN pg_namespace n ON n.oid = con.connamespace
  JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = ANY (con.conkey)
 WHERE n.nspname = 'dw' AND con.contype = 'f'
 ORDER BY 1, 2;

-- 3) Tipos de dato de todas las columnas
SELECT table_name  AS tabla,
       column_name AS columna,
       data_type ||
         COALESCE('(' || character_maximum_length || ')', '') ||
         CASE WHEN numeric_precision IS NOT NULL AND data_type = 'numeric'
              THEN '(' || numeric_precision || ',' || numeric_scale || ')' ELSE '' END AS tipo,
       is_nullable AS admite_nulos
  FROM information_schema.columns
 WHERE table_schema = 'dw'
 ORDER BY table_name, ordinal_position;

-- 4) Registros por tabla (para la columna «Registros» de la tabla 1.2)
SELECT 'dim_tiempo' AS tabla, count(*) AS registros FROM dw.dim_tiempo
UNION ALL SELECT 'dim_localidad',            count(*) FROM dw.dim_localidad
UNION ALL SELECT 'dim_tipo_alojamiento',     count(*) FROM dw.dim_tipo_alojamiento
UNION ALL SELECT 'dim_tipo_hurto',           count(*) FROM dw.dim_tipo_hurto
UNION ALL SELECT 'dim_caracteristica_hurto', count(*) FROM dw.dim_caracteristica_hurto
UNION ALL SELECT 'fact_dinamica_empresarial',count(*) FROM dw.fact_dinamica_empresarial
UNION ALL SELECT 'fact_alojamiento',         count(*) FROM dw.fact_alojamiento
UNION ALL SELECT 'fact_hurtos',              count(*) FROM dw.fact_hurtos;
