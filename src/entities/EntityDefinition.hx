package entities;

typedef EntityDefinition = {
    var className:String;
    var tableName:String;
    var primaryKeyFieldName:String;
    var primaryKeyFieldType:EntityFieldType;
    var ?primaryKeyFieldAutoIncrement:Bool;
    var fields:Array<EntityFieldDefinition>;
    var ?indexes:Array<Array<String>>;
}