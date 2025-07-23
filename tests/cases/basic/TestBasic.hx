package cases.basic;

import entities.EntityManager;
import cases.basic.entities.BasicEntity;
import utest.Assert;
import utest.Async;
import db.IDatabase;
import cases.basic.entities.Initializer.*;

@:timeout(10000)
class TestBasic extends TestBase {
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

    function testBasic_Primitives(async:Async) {
        var entity1 = createEntity("this is a string value for entity #1", 123, 456.789, true, new Date(2000, 2, 3, 4, 5, 6));

        profileStart("testBasic_Primitives");
        measureStart("add()");
        entity1.add().then(entity -> {
            measureEnd("add()");

            Assert.equals(1, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1", entity.stringValue);
            Assert.equals(123, entity.intValue);
            Assert.equals(456.789, entity.floatValue);
            Assert.equals(true, entity.boolValue);
            Assert.equals(new Date(2000, 2, 3, 4, 5, 6).toString(), entity1.dateValue.toString());

            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");

            Assert.equals(1, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1", entity.stringValue);
            Assert.equals(123, entity.intValue);
            Assert.equals(456.789, entity.floatValue);
            Assert.equals(true, entity.boolValue);
            Assert.equals(new Date(2000, 2, 3, 4, 5, 6).toString(), entity.dateValue.toString());

            entity.stringValue += " - addition";
            entity.intValue *= 2;
            entity.floatValue /= 2;
            entity.boolValue = !entity.boolValue;
            entity.dateValue = new Date(2001, 3, 4, 5, 6, 7);

            measureStart("update()");
            return entity.update();
        }).then(entity -> {
            measureEnd("update()");
            Assert.equals(1, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1 - addition", entity.stringValue);
            Assert.equals(246, entity.intValue);
            Assert.equals(228.3945, entity.floatValue);
            Assert.equals(false, entity.boolValue);
            Assert.equals(new Date(2001, 3, 4, 5, 6, 7).toString(), entity.dateValue.toString());

            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals(1, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1 - addition", entity.stringValue);
            Assert.equals(246, entity.intValue);
            Assert.equals(228.3945, entity.floatValue);
            Assert.equals(false, entity.boolValue);

            Assert.equals(new Date(2001, 3, 4, 5, 6, 7).toString(), entity.dateValue.toString());
            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_Primitives_Properties(async:Async) {
        var entity1 = createEntity("this is a string value for entity #1", 123, 456.789, true, new Date(2000, 2, 3, 4, 5, 6));
        entity1.primitiveProperty = 123456;
        entity1.entityProperty = new BasicEntity();
        entity1.entityProperty.primitiveProperty = 654321;

        profileStart("testBasic_Primitives");
        measureStart("add()");
        entity1.add().then(entity -> {
            measureEnd("add()");

            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1", entity.stringValue);
            Assert.equals(123, entity.intValue);
            Assert.equals(456.789, entity.floatValue);
            Assert.equals(true, entity.boolValue);
            Assert.equals(new Date(2000, 2, 3, 4, 5, 6).toString(), entity1.dateValue.toString());

            measureStart("findById()");
            return BasicEntity.findById(2);
        }).then(entity -> {
            measureEnd("findById()");

            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1", entity.stringValue);
            Assert.equals(123, entity.intValue);
            Assert.equals(456.789, entity.floatValue);
            Assert.equals(true, entity.boolValue);
            Assert.equals(new Date(2000, 2, 3, 4, 5, 6).toString(), entity.dateValue.toString());

            entity.stringValue += " - addition";
            entity.intValue *= 2;
            entity.floatValue /= 2;
            entity.boolValue = !entity.boolValue;
            entity.dateValue = new Date(2001, 3, 4, 5, 6, 7);

            measureStart("update()");
            return entity.update();
        }).then(entity -> {
            measureEnd("update()");
            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1 - addition", entity.stringValue);
            Assert.equals(246, entity.intValue);
            Assert.equals(228.3945, entity.floatValue);
            Assert.equals(false, entity.boolValue);
            Assert.equals(new Date(2001, 3, 4, 5, 6, 7).toString(), entity.dateValue.toString());

            measureStart("findById()");
            return BasicEntity.findById(2);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals(2, entity.basicEntityId);
            Assert.equals("this is a string value for entity #1 - addition", entity.stringValue);
            Assert.equals(246, entity.intValue);
            Assert.equals(228.3945, entity.floatValue);
            Assert.equals(false, entity.boolValue);

            Assert.equals(new Date(2001, 3, 4, 5, 6, 7).toString(), entity.dateValue.toString());
            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_PrimitiveArrays_String(async:Async) {
        var entity1 = createEntity("entity1");
        entity1.stringArray1 = ["string 1A", "string 1B", "string 1C"];
        entity1.stringArray2 = ["string 2A", "string 2B"];

        profileStart("testBasic_PrimitiveArrays_String");
        measureStart("add()");
        entity1.add().then(entity -> {
            measureEnd("add()");
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.stringArray1.length);
            Assert.equals("string 1A", entity.stringArray1[0]);
            Assert.equals("string 1B", entity.stringArray1[1]);
            Assert.equals("string 1C", entity.stringArray1[2]);
            Assert.equals(2, entity.stringArray2.length);
            Assert.equals("string 2A", entity.stringArray2[0]);
            Assert.equals("string 2B", entity.stringArray2[1]);
            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.stringArray1.length);
            Assert.equals("string 1A", entity.stringArray1[0]);
            Assert.equals("string 1B", entity.stringArray1[1]);
            Assert.equals("string 1C", entity.stringArray1[2]);
            Assert.equals(2, entity.stringArray2.length);
            Assert.equals("string 2A", entity.stringArray2[0]);
            Assert.equals("string 2B", entity.stringArray2[1]);

            entity.stringArray1[0] += " - edited 1";
            entity.stringArray1[2] += " - edited 2";
            entity.stringArray2[0] += " - edited 3";

            measureStart("update()");
            return entity.update();
        }).then(entity -> {
            measureEnd("update()");
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.stringArray1.length);
            Assert.equals("string 1A - edited 1", entity.stringArray1[0]);
            Assert.equals("string 1B", entity.stringArray1[1]);
            Assert.equals("string 1C - edited 2", entity.stringArray1[2]);
            Assert.equals(2, entity.stringArray2.length);
            Assert.equals("string 2A - edited 3", entity.stringArray2[0]);
            Assert.equals("string 2B", entity.stringArray2[1]);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_PrimitiveArrays_Bool(async:Async) {
        var entity1 = createEntity("entity1");
        entity1.boolArray1 = [true, false, false];
        entity1.boolArray2 = [false, true];

        profileStart("testBasic_PrimitiveArrays_Bool");
        entity1.add().then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.boolArray1.length);
            Assert.equals(true, entity.boolArray1[0]);
            Assert.equals(false, entity.boolArray1[1]);
            Assert.equals(false, entity.boolArray1[2]);
            Assert.equals(2, entity.boolArray2.length);
            Assert.equals(false, entity.boolArray2[0]);
            Assert.equals(true, entity.boolArray2[1]);
            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.boolArray1.length);
            Assert.equals(true, entity.boolArray1[0]);
            Assert.equals(false, entity.boolArray1[1]);
            Assert.equals(false, entity.boolArray1[2]);
            Assert.equals(2, entity.boolArray2.length);
            Assert.equals(false, entity.boolArray2[0]);
            Assert.equals(true, entity.boolArray2[1]);

            entity.boolArray1[0] = !entity.boolArray1[0];
            entity.boolArray1[2] = !entity.boolArray1[2];
            entity.boolArray2[0] = !entity.boolArray2[0];

            return entity.update();
        }).then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.boolArray1.length);
            Assert.equals(false, entity.boolArray1[0]);
            Assert.equals(false, entity.boolArray1[1]);
            Assert.equals(true, entity.boolArray1[2]);
            Assert.equals(2, entity.boolArray2.length);
            Assert.equals(true, entity.boolArray2[0]);
            Assert.equals(true, entity.boolArray2[1]);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_PrimitiveArrays_String_And_Bool(async:Async) {
        var entity1 = createEntity("entity1");
        entity1.stringArray1 = ["string 1A", "string 1B", "string 1C"];
        entity1.stringArray2 = ["string 2A", "string 2B"];
        entity1.boolArray1 = [true, false, false];
        entity1.boolArray2 = [false, true];

        profileStart("testBasic_PrimitiveArrays_String_And_Bool");
        entity1.add().then(entity -> {
            Assert.equals("entity1", entity.stringValue);

            Assert.equals(3, entity.stringArray1.length);
            Assert.equals("string 1A", entity.stringArray1[0]);
            Assert.equals("string 1B", entity.stringArray1[1]);
            Assert.equals("string 1C", entity.stringArray1[2]);
            Assert.equals(2, entity.stringArray2.length);
            Assert.equals("string 2A", entity.stringArray2[0]);
            Assert.equals("string 2B", entity.stringArray2[1]);

            Assert.equals(3, entity.boolArray1.length);
            Assert.equals(true, entity.boolArray1[0]);
            Assert.equals(false, entity.boolArray1[1]);
            Assert.equals(false, entity.boolArray1[2]);
            Assert.equals(2, entity.boolArray2.length);
            Assert.equals(false, entity.boolArray2[0]);
            Assert.equals(true, entity.boolArray2[1]);

            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("entity1", entity.stringValue);

            Assert.equals(3, entity.stringArray1.length);
            Assert.equals("string 1A", entity.stringArray1[0]);
            Assert.equals("string 1B", entity.stringArray1[1]);
            Assert.equals("string 1C", entity.stringArray1[2]);
            Assert.equals(2, entity.stringArray2.length);
            Assert.equals("string 2A", entity.stringArray2[0]);
            Assert.equals("string 2B", entity.stringArray2[1]);

            Assert.equals(3, entity.boolArray1.length);
            Assert.equals(true, entity.boolArray1[0]);
            Assert.equals(false, entity.boolArray1[1]);
            Assert.equals(false, entity.boolArray1[2]);
            Assert.equals(2, entity.boolArray2.length);
            Assert.equals(false, entity.boolArray2[0]);
            Assert.equals(true, entity.boolArray2[1]);

            entity.stringArray1[0] += " - edited 1";
            entity.stringArray1[2] += " - edited 2";
            entity.stringArray2[0] += " - edited 3";
            entity.boolArray1[0] = !entity.boolArray1[0];
            entity.boolArray1[2] = !entity.boolArray1[2];
            entity.boolArray2[0] = !entity.boolArray2[0];

            return entity.update();
        }).then(entity -> {
            Assert.equals("entity1", entity.stringValue);

            Assert.equals(3, entity.stringArray1.length);
            Assert.equals("string 1A - edited 1", entity.stringArray1[0]);
            Assert.equals("string 1B", entity.stringArray1[1]);
            Assert.equals("string 1C - edited 2", entity.stringArray1[2]);
            Assert.equals(2, entity.stringArray2.length);
            Assert.equals("string 2A - edited 3", entity.stringArray2[0]);
            Assert.equals("string 2B", entity.stringArray2[1]);

            Assert.equals(3, entity.boolArray1.length);
            Assert.equals(false, entity.boolArray1[0]);
            Assert.equals(false, entity.boolArray1[1]);
            Assert.equals(true, entity.boolArray1[2]);
            Assert.equals(2, entity.boolArray2.length);
            Assert.equals(true, entity.boolArray2[0]);
            Assert.equals(true, entity.boolArray2[1]);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_PrimitiveArrays_Int(async:Async) {
        var entity1 = createEntity("entity1");
        entity1.intArray1 = [111, 222, 333];
        entity1.intArray2 = [444, 555];

        profileStart("testBasic_PrimitiveArrays_Int");
        entity1.add().then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.intArray1.length);
            Assert.equals(111, entity.intArray1[0]);
            Assert.equals(222, entity.intArray1[1]);
            Assert.equals(333, entity.intArray1[2]);
            Assert.equals(2, entity.intArray2.length);
            Assert.equals(444, entity.intArray2[0]);
            Assert.equals(555, entity.intArray2[1]);
            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.intArray1.length);
            Assert.equals(111, entity.intArray1[0]);
            Assert.equals(222, entity.intArray1[1]);
            Assert.equals(333, entity.intArray1[2]);
            Assert.equals(2, entity.intArray2.length);
            Assert.equals(444, entity.intArray2[0]);
            Assert.equals(555, entity.intArray2[1]);

            entity.intArray1[0] *= 2;
            entity.intArray1[2] *= 3;
            entity.intArray2[0] *= 4;

            return entity.update();
        }).then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.intArray1.length);
            Assert.equals(222, entity.intArray1[0]);
            Assert.equals(222, entity.intArray1[1]);
            Assert.equals(999, entity.intArray1[2]);
            Assert.equals(2, entity.intArray2.length);
            Assert.equals(1776, entity.intArray2[0]);
            Assert.equals(555, entity.intArray2[1]);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_PrimitiveArrays_Float(async:Async) {
        var entity1 = createEntity("entity1");
        entity1.floatArray1 = [111.11, 222.22, 333.33];
        entity1.floatArray2 = [444.44, 555.55];

        profileStart("testBasic_PrimitiveArrays_Float");
        entity1.add().then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.floatArray1.length);
            Assert.equals(111.11, entity.floatArray1[0]);
            Assert.equals(222.22, entity.floatArray1[1]);
            Assert.equals(333.33, entity.floatArray1[2]);
            Assert.equals(2, entity.floatArray2.length);
            Assert.equals(444.44, entity.floatArray2[0]);
            Assert.equals(555.55, entity.floatArray2[1]);
            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.floatArray1.length);
            Assert.equals(111.11, entity.floatArray1[0]);
            Assert.equals(222.22, entity.floatArray1[1]);
            Assert.equals(333.33, entity.floatArray1[2]);
            Assert.equals(2, entity.floatArray2.length);
            Assert.equals(444.44, entity.floatArray2[0]);
            Assert.equals(555.55, entity.floatArray2[1]);

            entity.floatArray1[0] *= 2;
            entity.floatArray1[2] *= 3;
            entity.floatArray2[0] *= 4;

            return entity.update();
        }).then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.floatArray1.length);
            Assert.equals(222.22, entity.floatArray1[0]);
            Assert.equals(222.22, entity.floatArray1[1]);
            Assert.equals(999.99, entity.floatArray1[2]);
            Assert.equals(2, entity.floatArray2.length);
            Assert.equals(1777.76, entity.floatArray2[0]);
            Assert.equals(555.55, entity.floatArray2[1]);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_PrimitiveArrays_Date(async:Async) {
        var entity1 = createEntity("entity1");
        entity1.dateArray1 = [new Date(2000, 1, 2, 3, 4, 5), new Date(2001, 2, 3, 4, 5, 6), new Date(2002, 3, 4, 5, 6, 7)];
        entity1.dateArray2 = [new Date(2003, 4, 5, 6, 7, 8), new Date(2004, 5, 6, 7, 8, 9)];

        profileStart("testBasic_PrimitiveArrays_Date");
        entity1.add().then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.dateArray1.length);
            Assert.equals(new Date(2000, 1, 2, 3, 4, 5).toString(), entity.dateArray1[0].toString());
            Assert.equals(new Date(2001, 2, 3, 4, 5, 6).toString(), entity.dateArray1[1].toString());
            Assert.equals(new Date(2002, 3, 4, 5, 6, 7).toString(), entity.dateArray1[2].toString());
            Assert.equals(2, entity.dateArray2.length);
            Assert.equals(new Date(2003, 4, 5, 6, 7, 8).toString(), entity.dateArray2[0].toString());
            Assert.equals(new Date(2004, 5, 6, 7, 8, 9).toString(), entity.dateArray2[1].toString());
            measureStart("findById()");
            return BasicEntity.findById(1);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.dateArray1.length);
            Assert.equals(new Date(2000, 1, 2, 3, 4, 5).toString(), entity.dateArray1[0].toString());
            Assert.equals(new Date(2001, 2, 3, 4, 5, 6).toString(), entity.dateArray1[1].toString());
            Assert.equals(new Date(2002, 3, 4, 5, 6, 7).toString(), entity.dateArray1[2].toString());
            Assert.equals(2, entity.dateArray2.length);
            Assert.equals(new Date(2003, 4, 5, 6, 7, 8).toString(), entity.dateArray2[0].toString());
            Assert.equals(new Date(2004, 5, 6, 7, 8, 9).toString(), entity.dateArray2[1].toString());

            entity.dateArray1[0] = new Date(2010, 9, 10, 11, 12, 13);
            entity.dateArray1[2] = new Date(2012, 10, 11, 12, 13, 14);
            entity.dateArray2[0] = new Date(2013, 11, 12, 13, 14, 15);

            return entity.update();
        }).then(entity -> {
            Assert.equals("entity1", entity.stringValue);
            Assert.equals(3, entity.dateArray1.length);
            Assert.equals(new Date(2010, 9, 10, 11, 12, 13).toString(), entity.dateArray1[0].toString());
            Assert.equals(new Date(2001, 2, 3, 4, 5, 6).toString(), entity.dateArray1[1].toString());
            Assert.equals(new Date(2012, 10, 11, 12, 13, 14).toString(), entity.dateArray1[2].toString());
            Assert.equals(2, entity.dateArray2.length);
            Assert.equals(new Date(2013, 11, 12, 13, 14, 15).toString(), entity.dateArray2[0].toString());
            Assert.equals(new Date(2004, 5, 6, 7, 8, 9).toString(), entity.dateArray2[1].toString());

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_OneToOne(async:Async) {
        var mainEntity = createEntity("mainEntity", 111);
        mainEntity.entity1 = createEntity("entity1", 123);
        mainEntity.entity2 = createEntity("entity2", 456);

        profileStart("testBasic_OneToOne");
        mainEntity.add().then(mainEntity -> {
            Assert.equals("mainEntity", mainEntity.stringValue);
            Assert.equals(111, mainEntity.intValue);

            Assert.equals("entity1", mainEntity.entity1.stringValue);
            Assert.equals(123, mainEntity.entity1.intValue);

            Assert.equals("entity2", mainEntity.entity2.stringValue);
            Assert.equals(456, mainEntity.entity2.intValue);
            
            measureStart("findById()");
            return BasicEntity.findById(mainEntity.basicEntityId);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("mainEntity", entity.stringValue);
            Assert.equals(111, entity.intValue);

            Assert.equals("entity1", entity.entity1.stringValue);
            Assert.equals(123, entity.entity1.intValue);

            Assert.equals("entity2", entity.entity2.stringValue);
            Assert.equals(456, entity.entity2.intValue);

            entity.stringValue += " - edited 1";
            entity.entity1.stringValue += " - edited 2";
            entity.entity2.stringValue += " - edited 3";

            return entity.update();
        }).then(entity -> {
            return BasicEntity.findById(entity.basicEntityId);
        }).then(entity -> {
            Assert.equals("mainEntity - edited 1", entity.stringValue);
            Assert.equals(111, entity.intValue);

            Assert.equals("entity1 - edited 2", entity.entity1.stringValue);
            Assert.equals(123, entity.entity1.intValue);

            Assert.equals("entity2 - edited 3", entity.entity2.stringValue);
            Assert.equals(456, entity.entity2.intValue);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_OneToMany(async:Async) {
        var mainEntity = createEntity("mainEntity", 111);
        mainEntity.entitiesArray1 = [createEntity("entity 1A"), createEntity("entity 1B"), createEntity("entity 1C")];
        mainEntity.entitiesArray2 = [createEntity("entity 2A"), createEntity("entity 2B")];

        profileStart("testBasic_OneToMany");
        mainEntity.add().then(mainEntity -> {
            Assert.equals("mainEntity", mainEntity.stringValue);
            Assert.equals(111, mainEntity.intValue);

            Assert.equals(3, mainEntity.entitiesArray1.length);
            Assert.equals("entity 1A", mainEntity.entitiesArray1[0].stringValue);
            Assert.equals("entity 1B", mainEntity.entitiesArray1[1].stringValue);
            Assert.equals("entity 1C", mainEntity.entitiesArray1[2].stringValue);

            Assert.equals(2, mainEntity.entitiesArray2.length);
            Assert.equals("entity 2A", mainEntity.entitiesArray2[0].stringValue);
            Assert.equals("entity 2B", mainEntity.entitiesArray2[1].stringValue);
            
            measureStart("findById()");
            return BasicEntity.findById(mainEntity.basicEntityId);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("mainEntity", entity.stringValue);
            Assert.equals(111, entity.intValue);

            Assert.equals(3, entity.entitiesArray1.length);
            Assert.equals("entity 1A", entity.entitiesArray1[0].stringValue);
            Assert.equals("entity 1B", entity.entitiesArray1[1].stringValue);
            Assert.equals("entity 1C", entity.entitiesArray1[2].stringValue);

            Assert.equals(2, entity.entitiesArray2.length);
            Assert.equals("entity 2A", entity.entitiesArray2[0].stringValue);
            Assert.equals("entity 2B", entity.entitiesArray2[1].stringValue);

            entity.stringValue += " - edited 1";
            entity.entitiesArray1[0].stringValue += " - edited 2";
            entity.entitiesArray1[2].stringValue += " - edited 3";
            entity.entitiesArray2[1].stringValue += " - edited 4";

            return entity.update();
        }).then(entity -> {
            measureStart("findById()");
            return BasicEntity.findById(entity.basicEntityId);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("mainEntity - edited 1", entity.stringValue);
            Assert.equals(111, entity.intValue);

            Assert.equals(3, entity.entitiesArray1.length);
            Assert.equals("entity 1A - edited 2", entity.entitiesArray1[0].stringValue);
            Assert.equals("entity 1B", entity.entitiesArray1[1].stringValue);
            Assert.equals("entity 1C - edited 3", entity.entitiesArray1[2].stringValue);

            Assert.equals(2, entity.entitiesArray2.length);
            Assert.equals("entity 2A", entity.entitiesArray2[0].stringValue);
            Assert.equals("entity 2B - edited 4", entity.entitiesArray2[1].stringValue);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_Size_String(async:Async) {
        var mainEntity = createEntity("mainEntity", 111);
        mainEntity.limitedStringValue = "this string is over the 20 char limit for the field";

        profileStart("testBasic_OneToMany");
        mainEntity.add().then(mainEntity -> {
            Assert.equals("mainEntity", mainEntity.stringValue);
            Assert.equals(111, mainEntity.intValue);
            
            measureStart("findById()");
            return BasicEntity.findById(mainEntity.basicEntityId);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("mainEntity", entity.stringValue);
            Assert.equals(111, entity.intValue);
            Assert.equals("this string is over ", entity.limitedStringValue);

            entity.limitedStringValue = "123456789012345678901234567890";
            return entity.update();
        }).then(entity -> {
            return BasicEntity.findById(entity.basicEntityId);
        }).then(entity -> {
            Assert.equals("mainEntity", entity.stringValue);
            Assert.equals(111, entity.intValue);
            Assert.equals("12345678901234567890", entity.limitedStringValue);

            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }

    function testBasic_Size_String_NoTruncate(async:Async) {
        var mainEntity = createEntity("mainEntity", 111);
        mainEntity.limitedStringValueNoTruncate = "this string is over the 20 char limit for the field";

        mainEntity.add().then(mainEntity -> {
            Assert.fail("db should throw an error about the size constraint");
            async.done();
        }, error -> {
            Assert.pass();
            async.done();
        });
    }

    function testBasic_QueryCache(async:Async) {        
        var mainEntity = createEntity("mainEntity");
        var entity1 = createEntity("entity1");
        var entity2 = createEntity("entity2");
        mainEntity.entity1 = entity1;
        mainEntity.entity2 = entity2;
        mainEntity.entity3 = entity1;
        mainEntity.entity4 = entity2;
        mainEntity.entitiesArray1 = [entity1, entity2];
        mainEntity.entitiesArray2 = [entity1, entity2];
        mainEntity.entitiesArray3 = [entity1, entity2];
        mainEntity.entitiesArray4 = [entity1, entity2];

        profileStart("testBasic_QueryCache");
        mainEntity.add().then(mainEntity -> {
            Assert.equals("mainEntity", mainEntity.stringValue);
            measureStart("findById()");
            return BasicEntity.findById(mainEntity.basicEntityId);
        }).then(entity -> {
            measureEnd("findById()");
            Assert.equals("mainEntity", mainEntity.stringValue);
            Assert.equals("entity1", mainEntity.entity1.stringValue);
            Assert.equals("entity2", mainEntity.entity2.stringValue);
            Assert.equals("entity1", mainEntity.entity3.stringValue);
            Assert.equals("entity2", mainEntity.entity4.stringValue);
            Assert.equals("entity1", mainEntity.entitiesArray1[0].stringValue);
            Assert.equals("entity2", mainEntity.entitiesArray1[1].stringValue);
            Assert.equals("entity1", mainEntity.entitiesArray2[0].stringValue);
            Assert.equals("entity2", mainEntity.entitiesArray2[1].stringValue);
            Assert.equals("entity1", mainEntity.entitiesArray3[0].stringValue);
            Assert.equals("entity2", mainEntity.entitiesArray3[1].stringValue);
            Assert.equals("entity1", mainEntity.entitiesArray4[0].stringValue);
            Assert.equals("entity2", mainEntity.entitiesArray4[1].stringValue);
            Assert.equals(507, @:privateAccess EntityManager.instance._queryCacheHitCount); // is 507 too specific?
            profileEnd();
            async.done();
        }, error -> {
            trace("ERROR", error);
        });
    }
}