package entities.macros;

#if macro

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.Tools;
using entities.macros.helpers.MacroTypeTools;
using entities.macros.EntityTypeTools;

class EntityComplexTypeTools {
    public static function isEntity(complexType:ComplexType):Bool {
        return complexType.toType().isEntity();
    }

    public static function toComplexType(field:EntityFieldDefinition):ComplexType {
        return null;
    }

    // we'll pass in the entity def here, this means we'll create the classDef relative to the entity def package, this can
    // remove some chances of naming collisions
    public static function toClassDefExpr(field:EntityFieldDefinition, entityDefinition:EntityDefinition):Array<String> {
        var classDef = null;
        switch (field.type) {
            case Entity(className, relationship, type):
                switch (relationship) {
                    case OneToOne(table1, field1, table2, field2):
                        classDef = className.split(".");
                    case OneToMany(table1, field1, table2, field2):
                        classDef = className.split(".");
                }
            case _:    
        }
        if (entityDefinition != null) {
            var entityClassPath = entityDefinition.className.split(".");
            var classDefCopy = classDef.copy();
            entityClassPath.pop();
            classDefCopy.pop();
            if (entityClassPath.join(".") == classDefCopy.join(".")) {
                classDef = [classDef.pop()];
            }
        }
        return classDef;
    }

    public static function primitiveEntityTypePath(field:EntityFieldDefinition):TypePath {
        return primitiveEntityTypePathFromType(field.primitiveType);
    }

    public static function primitiveEntityTypePathFromType(type:String):TypePath {
        var typePath:TypePath = null;
        switch (type) {
            case "Bool":
                typePath = {name: "EntityBoolPrimitive", pack: ["entities", "primitives"]};
            case "Int":
                typePath = {name: "EntityIntPrimitive", pack: ["entities", "primitives"]};
            case "Float":
                typePath = {name: "EntityFloatPrimitive", pack: ["entities", "primitives"]};
            case "String":
                typePath = {name: "EntityStringPrimitive", pack: ["entities", "primitives"]};
            case "Date":
                typePath = {name: "EntityDatePrimitive", pack: ["entities", "primitives"]};
            case _:
                Context.error("unknown primitive type", Context.currentPos());
        }
        return typePath;
    }
}

#end