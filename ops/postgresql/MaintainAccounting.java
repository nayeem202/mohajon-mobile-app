import com.fasterxml.jackson.databind.ObjectMapper;
import com.haalkhata.core.security.CurrentUser;
import com.haalkhata.feature.accounting.application.AccountingService;
import com.haalkhata.feature.accounting.infrastructure.AccountingSources;
import com.haalkhata.feature.accounting.infrastructure.AccountingStore;
import java.math.BigDecimal;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.flywaydb.core.Flyway;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;

/** Local PostgreSQL V60 maintenance. Credentials are environment-only.
 * Run with the business service runtime classpath and Java 21 source launch.
 * No clean, repair, baseline or application startup is performed. */
public class MaintainAccounting {
    public static void main(String[] arguments) throws Exception {
        if (arguments.length != 2 || !List.of("info", "migrate", "verify", "smoke").contains(arguments[0])) {
            throw new IllegalArgumentException("Usage: MaintainAccounting.java info|migrate|verify|smoke migration-directory");
        }
        String url = required("ACCOUNTING_DB_URL");
        String schema = required("ACCOUNTING_DB_SCHEMA");
        if (!url.matches("jdbc:postgresql://127\\.0\\.0\\.1:5432/authdb\\?currentSchema=[a-z0-9_]+")
                || !(schema.equals("hk") || schema.matches("qa_accounting_migration_[0-9]{8}"))
                || !url.endsWith("currentSchema=" + schema)) {
            throw new IllegalArgumentException("This runner is restricted to the explicitly selected local authdb schema");
        }
        var source = new DriverManagerDataSource(url, required("ACCOUNTING_DB_USER"), required("ACCOUNTING_DB_PASSWORD"));
        var jdbc = new JdbcTemplate(source);
        if (!schema.equals(jdbc.queryForObject("select current_schema()", String.class))) {
            throw new IllegalStateException("Unexpected database search path");
        }
        var flyway = Flyway.configure().dataSource(source).schemas(schema).defaultSchema(schema)
                .locations("filesystem:" + Path.of(arguments[1]).toAbsolutePath())
                .target("60").createSchemas(false).baselineOnMigrate(false).cleanDisabled(true)
                .validateOnMigrate(true).outOfOrder(false).lockRetryCount(5).load();
        // Standalone validate rejects expected pending migrations. Migrate
        // validates applied checksums itself before applying pending versions.
        if (arguments[0].equals("verify") || arguments[0].equals("smoke")) flyway.validate();
        System.out.println("DATABASE=authdb SCHEMA=" + schema + " COMMAND=" + arguments[0]);
        switch (arguments[0]) {
            case "info" -> {
                System.out.println("CURRENT_VERSION=" + flyway.info().current().getVersion());
                for (var migration : flyway.info().pending()) {
                    System.out.println("PENDING=" + migration.getVersion() + " " + migration.getDescription());
                }
            }
            case "migrate" -> {
                var result = flyway.migrate();
                System.out.println("MIGRATIONS_EXECUTED=" + result.migrationsExecuted);
                System.out.println("CURRENT_VERSION=" + flyway.info().current().getVersion());
            }
            case "verify" -> {
                if (!"60".equals(flyway.info().current().getVersion().toString()) || flyway.info().pending().length != 0) {
                    throw new IllegalStateException("V60 is not the fully applied, validated schema version");
                }
                for (String table : List.of("accounting_setups", "accounting_entries", "accounting_classifications",
                        "accounting_journals", "accounting_journal_lines", "accounting_source_states")) {
                    if (!Boolean.TRUE.equals(jdbc.queryForObject("select to_regclass(?) is not null", Boolean.class, schema + "." + table))) {
                        throw new IllegalStateException("Missing accounting table: " + table);
                    }
                }
                int columns = jdbc.queryForObject("select count(*) from information_schema.columns where table_schema=? and table_name='sales' and column_name in ('original_total_amount','initial_paid_amount','initial_payment_id')", Integer.class, schema);
                if (columns != 3) throw new IllegalStateException("Missing original invoice/payment columns");
                int forced = jdbc.queryForObject("select count(*) from app_update_policies where force_update_enabled", Integer.class);
                if (forced != 0) throw new IllegalStateException("Unexpected enabled force-update policy");
                System.out.println("VERIFIED=V60; six accounting tables; three invoice columns; force-update off");
            }
            case "smoke" -> smoke(source, jdbc);
            default -> throw new IllegalArgumentException("Unknown operation");
        }
    }

    private static void smoke(DriverManagerDataSource source, JdbcTemplate jdbc) {
        String id = UUID.randomUUID().toString(), shop = "pgcheck-" + id, branch = shop + "-main";
        LocalDate today = LocalDate.now(ZoneId.of("Asia/Dhaka"));
        var owner = new CurrentUser(id, "qa@example.test", "Migration check", shop, "OWNER", List.of("OWNER"), branch);
        var store = new AccountingStore(jdbc, new ObjectMapper().findAndRegisterModules());
        var service = new AccountingService(store, new AccountingSources(jdbc));
        var transaction = new TransactionTemplate(new DataSourceTransactionManager(source));
        transaction.executeWithoutResult(status -> {
            status.setRollbackOnly(); // Never leave test shops or financial entries behind.
            jdbc.update("insert into shops(shop_id,owner_user_id,name,created_at,updated_at) values(?,?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)", shop, id, "Accounting migration verification");
            service.setup(owner, today, Map.of("CASH", 100, "CAPITAL", 100), true);
            var contribution = Map.<String,Object>of("entryId", UUID.randomUUID().toString(), "entryType", "CAPITAL_IN",
                    "businessDate", today.toString(), "amount", 50, "fundAccount", "CASH", "note", "Migration check contribution");
            service.addEntry(owner, contribution);
            service.addEntry(owner, contribution);
            int count = jdbc.queryForObject("select count(*) from accounting_entries where shop_id=?", Integer.class, shop);
            if (count != 1) throw new IllegalStateException("Stable transaction retry was not idempotent");
            var balance = service.balanceSheet(owner, today);
            if (!Boolean.TRUE.equals(balance.get("isBalanced")) || new BigDecimal(balance.get("totalAssets").toString()).compareTo(new BigDecimal("150")) != 0) {
                throw new IllegalStateException("Unexpected balanced opening/contribution result");
            }
            var income = service.income(owner, today, today);
            if (new BigDecimal(income.get("netProfit").toString()).signum() != 0) {
                throw new IllegalStateException("Capital was incorrectly recognized as profit");
            }
            if (service.journal(owner, today, today, 100).size() != 2) {
                throw new IllegalStateException("Unexpected journal count after duplicate retry");
            }
        });
        int remaining = jdbc.queryForObject("select count(*) from shops where shop_id=?", Integer.class, shop);
        int ledger = jdbc.queryForObject("select count(*) from accounting_setups where shop_id=?", Integer.class, shop);
        if (remaining != 0 || ledger != 0) throw new IllegalStateException("Smoke-test transaction did not roll back");
        System.out.println("SMOKE_PASS=real source queries; opening; idempotent entry; balanced statement; capital excluded from profit; journal; complete rollback");
    }

    private static String required(String name) {
        String value = System.getenv(name);
        if (value == null || value.isBlank()) throw new IllegalArgumentException("Missing environment variable: " + name);
        return value;
    }
}
