\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
-- Exclude the three newly-added NULL fields from the comparison. Read every
-- pre-existing application/auth table; no user data is printed, only hashes.
SELECT format(
    'SELECT %L AS table_name, count(*) AS rows, md5(coalesce(string_agg(md5((to_jsonb(t) - ARRAY[''original_total_amount'',''initial_paid_amount'',''initial_payment_id''])::text), '''' ORDER BY md5((to_jsonb(t) - ARRAY[''original_total_amount'',''initial_paid_amount'',''initial_payment_id''])::text)), '''')) AS fingerprint FROM %I.%I t;',
    schemaname||'.'||tablename, schemaname, tablename)
FROM pg_tables
WHERE schemaname IN ('hk','public') AND tablename <> 'flyway_schema_history'
  AND tablename NOT LIKE 'accounting_%' AND tablename <> 'app_update_policies'
ORDER BY schemaname, tablename
\gexec
COMMIT;
