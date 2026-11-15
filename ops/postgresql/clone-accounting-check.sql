\set ON_ERROR_STOP on
-- Explicitly named, isolated clone in the same local database. No role changes.
BEGIN ISOLATION LEVEL REPEATABLE READ;
CREATE SCHEMA qa_accounting_migration_20261023 AUTHORIZATION auth;
DO $clone$
DECLARE item record;
BEGIN
    FOR item IN SELECT tablename FROM pg_tables WHERE schemaname='hk' ORDER BY tablename LOOP
        EXECUTE format('CREATE TABLE qa_accounting_migration_20261023.%I (LIKE hk.%I INCLUDING ALL)', item.tablename, item.tablename);
        EXECUTE format('INSERT INTO qa_accounting_migration_20261023.%I SELECT * FROM hk.%I', item.tablename, item.tablename);
    END LOOP;
    -- LIKE does not copy foreign keys. Recreate them within the clone, not hk.
    FOR item IN
        SELECT t.relname, c.conname, pg_get_constraintdef(c.oid) AS definition
        FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid
        JOIN pg_namespace n ON n.oid=t.relnamespace
        WHERE n.nspname='hk' AND c.contype='f'
    LOOP
        EXECUTE format('ALTER TABLE qa_accounting_migration_20261023.%I ADD CONSTRAINT %I %s',
            item.relname, item.conname, replace(item.definition, 'REFERENCES hk.', 'REFERENCES qa_accounting_migration_20261023.'));
    END LOOP;
END
$clone$;
COMMIT;
