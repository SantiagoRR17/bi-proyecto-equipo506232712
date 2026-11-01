-- =============================================================================
-- 00_crear_base_datos.sql
-- Observatorio Distrital de Actividad Económica, Turismo y Seguridad (Bogotá D.C.)
-- Motor: PostgreSQL 16
--
-- Crea la base de datos vacía. Se ejecuta UNA sola vez, conectado a la base
-- "postgres" (no a observatorio_bi) y fuera de una transacción: en DBeaver,
-- ejecutar con "Ejecutar script" (Alt+X) con el modo de commit automático.
-- Después, conectarse a observatorio_bi y ejecutar 01, 02 y 03.
-- =============================================================================

CREATE DATABASE observatorio_bi
    WITH ENCODING = 'UTF8'
         TEMPLATE = template0;

-- Si en Windows falla con: encoding "UTF8" does not match locale "Spanish_...1252"
-- usar esta variante (el DW no depende del orden alfabético de la base):
--
-- CREATE DATABASE observatorio_bi
--     WITH ENCODING = 'UTF8'
--          LC_COLLATE = 'C'
--          LC_CTYPE   = 'C'
--          TEMPLATE   = template0;

COMMENT ON DATABASE observatorio_bi IS
    'Data warehouse dimensional del Observatorio Distrital (proyecto final BI, equipo 506232712)';
