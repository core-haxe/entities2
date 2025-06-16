package;

import db.DatabaseFactory;
import db.IDatabase;
import utest.ui.common.HeaderDisplayMode;
import utest.ui.Report;
import utest.Runner;
import cases.*;
import cases.basic.*;

class TestAll {
    public static var databaseBackend:String = null;

    public static function main() {
        var runner = new Runner();

        databaseBackend = Sys.getEnv("DB_CORE_BACKEND");
        if (databaseBackend == null) {
            databaseBackend = "mysql";
        }

        trace("DB_CORE_BACKEND: " + databaseBackend);
        if (databaseBackend == "sqlite") {
            addBasicCases(runner, sqlite("basic"));
        } else if (databaseBackend == "mysql") {
            trace("MYSQL_HOST: " + Sys.getEnv("MYSQL_HOST"));
            trace("MYSQL_USER: " + Sys.getEnv("MYSQL_USER"));
            trace("MYSQL_PASS: " + Sys.getEnv("MYSQL_PASS"));

            addBasicCases(runner, mysql("basic"));
            addGenericConfigCases(runner, mysql("genericconfig"));
            addRefsCases(runner, mysql("refs"));
        }

        Report.create(runner, SuccessResultsDisplayMode.AlwaysShowSuccessResults, HeaderDisplayMode.NeverShowHeader);
        runner.run();
        runner.onComplete.add((runner) -> {
            TestBase.displayCounts();
        });
    }

    private static function addBasicCases(runner:Runner, db:IDatabase) {
        runner.addCase(new cases.basic.TestBasic(db));
        runner.addCase(new cases.basic.TestAdd(db));
        runner.addCase(new cases.basic.TestDelete(db));
        runner.addCase(new cases.basic.TestFieldSets_Blacklist_Basic(db));
        runner.addCase(new cases.basic.TestLimit(db));
        runner.addCase(new cases.basic.TestPaging(db));
        runner.addCase(new cases.basic.TestRefs(db));
    }

    private static function addGenericConfigCases(runner:Runner, db:IDatabase) {
        runner.addCase(new cases.genericconfig.TestBasic(db));
        runner.addCase(new cases.genericconfig.TestUpdate(db));
        runner.addCase(new cases.genericconfig.TestComplex(db));
        runner.addCase(new cases.genericconfig.TestDelete(db));
    }

    private static function addRefsCases(runner:Runner, db:IDatabase) {
        runner.addCase(new cases.refs.TestOneToOne(db));
        runner.addCase(new cases.refs.TestOneToMany(db));
    }

    private static function sqlite(name:String):IDatabase {
        return DatabaseFactory.instance.createDatabase(DatabaseFactory.SQLITE, {
            filename: name + ".db"
        });
    }

    private static function mysql(name):IDatabase {
        return DatabaseFactory.instance.createDatabase(DatabaseFactory.MYSQL, {
            database: name,
            host: Sys.getEnv("MYSQL_HOST"),
            user: Sys.getEnv("MYSQL_USER"),
            pass: Sys.getEnv("MYSQL_PASS"),
            port: 3308
        });
    }
}