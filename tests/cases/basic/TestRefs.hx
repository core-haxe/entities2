package cases.basic;

import entities.EntityManager;
import cases.basic.entities.BasicEntity;
import utest.Assert;
import utest.Async;
import db.IDatabase;
import cases.basic.entities.Initializer.*;

@:timeout(10000)
class TestRefs extends TestBase {
    private var db:IDatabase;

    public function new(db:IDatabase) {
        super();
        this.db = db;
    }
    
    function setup(async:Async) {
        logging.LogManager.instance.addAdaptor(new logging.adaptors.ConsoleLogAdaptor({
            levels: [logging.LogLevel.Info]
        }));
        setupEntities(db).then(_ -> {
            async.done();
        });
    }

    function teardown(async:Async) {
        logging.LogManager.instance.clearAdaptors();
        teardownEntities(db).then(_ -> {
            async.done();
        });
    }

    function testBasic_NullRef(async:Async) {
        var mainEntity = createEntity("this is a string value for entity #1", 123, 456.789, true, new Date(2000, 2, 3, 4, 5, 6));
        mainEntity.entity1 = createEntity("sub entity", 456, 789.123, false, new Date(2001, 3, 4, 5, 6, 7));

        profileStart("testBasic_NullRef");
        measureStart("add()");
        mainEntity.add().then(entity -> {
            measureEnd("add()");

            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1", entity.stringValue);
            Assert.equals(123, entity.intValue);
            Assert.equals(456.789, entity.floatValue);
            Assert.equals(true, entity.boolValue);
            Assert.equals(new Date(2000, 2, 3, 4, 5, 6).toString(), entity.dateValue.toString());

            Assert.equals(1, entity.entity1.basicEntityId);
            Assert.equals("sub entity", entity.entity1.stringValue);
            Assert.equals(456, entity.entity1.intValue);
            Assert.equals(789.123, entity.entity1.floatValue);
            Assert.equals(false, entity.entity1.boolValue);
            Assert.equals(new Date(2001, 3, 4, 5, 6, 7).toString(), entity.entity1.dateValue.toString());

            measureStart("refresh()");
            return entity.refresh();
        }).then(entity -> {
            measureEnd("refresh()");

            Assert.notNull(entity.entity1);

            entity.entity1 = null;

            return entity.update();
        }).then(entity -> {
            Assert.isNull(entity.entity1);

            return entity.refresh();
        }).then(entity -> {
            Assert.isNull(entity.entity1);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_PartialUpdate(async:Async) {
        var mainEntity = createEntity("this is a string value for entity #1", 123, 456.789, true, new Date(2000, 2, 3, 4, 5, 6));
        mainEntity.entity1 = createEntity("sub entity", 456, 789.123, false, new Date(2001, 3, 4, 5, 6, 7));

        profileStart("testBasic_PartialUpdate");
        measureStart("add()");
        mainEntity.add().then(entity -> {
            measureEnd("add()");

            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1", entity.stringValue);
            Assert.equals(123, entity.intValue);
            Assert.equals(456.789, entity.floatValue);
            Assert.equals(true, entity.boolValue);
            Assert.equals(new Date(2000, 2, 3, 4, 5, 6).toString(), entity.dateValue.toString());

            Assert.equals(1, entity.entity1.basicEntityId);
            Assert.equals("sub entity", entity.entity1.stringValue);
            Assert.equals(456, entity.entity1.intValue);
            Assert.equals(789.123, entity.entity1.floatValue);
            Assert.equals(false, entity.entity1.boolValue);
            Assert.equals(new Date(2001, 3, 4, 5, 6, 7).toString(), entity.entity1.dateValue.toString());

            measureStart("refresh()");
            return entity.refresh();
        }).then(entity -> {
            measureEnd("refresh()");

            Assert.notNull(entity.entity1);

            // here we are creating a partial update, ie, just supplying the entity id and an update field
            // this should keep the sub entity intact with no changes, even though its not specified in the
            // partialEntity
            var partialEntity = new BasicEntity();
            partialEntity.basicEntityId = 2;
            partialEntity.stringValue = "this is an update";

            return partialEntity.update();
        }).then(entity -> {
            // since the update just returns "this", we would expect it to be null here
            Assert.isNull(entity.entity1);
            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is an update", entity.stringValue);

            return entity.refresh();
        }).then(entity -> {
            // however, after refreshing from the db, entity1 should be intact
            Assert.notNull(entity.entity1);
            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is an update", entity.stringValue);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }
}