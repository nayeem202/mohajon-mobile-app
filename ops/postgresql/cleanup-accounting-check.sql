\set ON_ERROR_STOP on
BEGIN;
DO $check$
BEGIN
    IF current_database() <> 'authdb' THEN RAISE EXCEPTION 'Unexpected database'; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname='qa_accounting_migration_20261023' AND nspowner=(SELECT oid FROM pg_roles WHERE rolname=current_user)) THEN
        RAISE EXCEPTION 'Temporary schema missing or not owned by the current user';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM hk.flyway_schema_history WHERE version='60' AND success)
       OR NOT EXISTS (SELECT 1 FROM qa_accounting_migration_20261023.flyway_schema_history WHERE version='60' AND success) THEN
        RAISE EXCEPTION 'Both migration checks must finish before cleanup';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_constraint c JOIN pg_class target ON c.confrelid=target.oid
        JOIN pg_namespace target_schema ON target.relnamespace=target_schema.oid
        JOIN pg_class source ON c.conrelid=source.oid
        JOIN pg_namespace source_schema ON source.relnamespace=source_schema.oid
        WHERE c.contype='f' AND target_schema.nspname='qa_accounting_migration_20261023'
          AND source_schema.nspname<>'qa_accounting_migration_20261023'
    ) THEN RAISE EXCEPTION 'An external table depends on the temporary schema'; END IF;
END
$check$;
DROP SCHEMA qa_accounting_migration_20261023 CASCADE;
COMMIT;
