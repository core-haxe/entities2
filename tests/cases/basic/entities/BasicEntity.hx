package cases.basic.entities;

import entities.IEntity;

@:fieldset(OnlyStringPrimitives, [stringValue])
@:fieldset(NoEntities, [!entity1, !entity2, !entity3, !entity4])
@:fieldset(NoEntityArrays, [!entitiesArray1, !entitiesArray2, !entitiesArray3, !entitiesArray4])
@:fieldset(OnlyStringPrimitiveArrays, [stringArray1, stringArray2])
@:fieldset(NoStringValue, [!stringValue])
@:exposeId
class BasicEntity implements IEntity {
    public var stringValue:String;
    public var intValue:Null<Int>;
    public var floatValue:Null<Float>;
    public var boolValue:Null<Bool>;
    public var dateValue:Date;

    public var basic:SomeAbstract;
    public var cases:String;

    public var entity1:BasicEntity = null;
    public var entity2:BasicEntity = null;
    @:cascade(deletions)
    public var entity3:BasicEntity = null;
    @:cascade(deletions)
    public var entity4:BasicEntity = null;

    public var entitiesArray1:Array<BasicEntity> = [];
    public var entitiesArray2:Array<BasicEntity> = [];
    @:cascade(deletions)
    public var entitiesArray3:Array<BasicEntity> = [];
    @:cascade(deletions)
    public var entitiesArray4:Array<BasicEntity> = [];

    public var stringArray1:Array<String> = [];
    public var stringArray2:Array<String> = [];

    public var boolArray1:Array<Bool> = [];
    public var boolArray2:Array<Bool> = [];

    public var intArray1:Array<Int> = [];
    public var intArray2:Array<Int> = [];

    public var floatArray1:Array<Float> = [];
    public var floatArray2:Array<Float> = [];

    public var dateArray1:Array<Date> = [];
    public var dateArray2:Array<Date> = [];

    @:size(20, truncate)
    public var limitedStringValue:String;
    @:size(20)
    public var limitedStringValueNoTruncate:String;

    @:ignore var _primitiveProperty:Int;
    public var primitiveProperty(get, set):Int;
    private function get_primitiveProperty():Int {
        return _primitiveProperty;
    }
    private function set_primitiveProperty(value:Int):Int {
        _primitiveProperty = value;
        return value;
    }

    @:ignore var _entityProperty:BasicEntity;
    public var entityProperty(get, set):BasicEntity;
    private function get_entityProperty():BasicEntity {
        return _entityProperty;
    }
    private function set_entityProperty(value:BasicEntity):BasicEntity {
        _entityProperty = value;
        return value;
    }

    @:ignore public var date:String;
    @:ignore public var time:String;
    public var timestamp(default, set):Timestamp;
    function set_timestamp(value) {
        date = DateTools.format(Date.fromTime(value), '%d/%m/%Y');
        time = DateTools.format(Date.fromTime(value), '%H:%M:%S');
        return timestamp = value;
    }
}