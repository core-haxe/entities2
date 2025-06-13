package entities.macros;

#if macro

import db.TableSchema;
import entities.macros.helpers.ClassBuilder;
import entities.macros.helpers.ClassField;
import entities.macros.helpers.ClassProperty;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.TypeTools;

using entities.EntityDefinitionTools;
using entities.macros.ClassBuilderTools;
using entities.macros.ClassVariableTools;
using entities.macros.EntityBuilderTools;
using entities.macros.EntityComplexTypeTools;
using entities.macros.TableSchemaTools;
using haxe.macro.Tools;

class EntityBuilder {
    macro static function build():Array<Field> {
        Sys.println("entities    > building entity '" + Context.getLocalClass().toString() + "'");
        var firstInterface = Context.getLocalClass().get().interfaces[0];
        if (firstInterface != null && firstInterface.t.toString() != "entities.IEntity") {
            Context.warning('IEntity interface should be the last on the interface list to ensure it gets processed first by haxe', Context.currentPos());
        }

        var entityClass = new ClassBuilder(Context.getBuildFields(), Context.getLocalType());
        var constructor = entityClass.createDefaultConstructor();

        var entityDefinition:EntityDefinition = {
            className: entityClass.qualifiedName,
            tableName: entityClass.tableName(),
            fields: [],
            primaryKeyFieldName: null,
            primaryKeyFieldType: null,
            indexes: []
        }
        entityClass.checkForPrimaryKeys(entityDefinition);
        //var entityComplexType = entityClass.toComplexType();

        if (entityClass.isExtern) {
            for (v in entityClass.varsAndProps) {
                if (v.isStatic) {
                    continue;
                }

                var fieldOptions:Array<EntityFieldOption> = v.entityFieldOptions();
                if (fieldOptions.contains(Ignore)) {
                    continue;
                }

                var complexType = TypeTools.toComplexType(Context.followWithAbstracts(ComplexTypeTools.toType(v.complexType)));
                switch (complexType) {
                    case (macro: $valueComplexType):
                        if (valueComplexType.isEntity()) {
                            v.remove();
                            var entityProp = entityClass.findOrCreateProperty(v.name, v.complexType, v.access, "get", "set");
                            entityProp.findOrCreateGetter().metadata.add(":noCompletion");
                            entityProp.findOrCreateSetter().metadata.add(":noCompletion");
                        }
                }
            }
        } else {
            entityClass.substitutePrimaryKeysInQueryCalls();

            var indexCandidates = entityClass.buildIndexCandidates();
            for (key in indexCandidates.keys()) {
                if (entityDefinition.indexes == null) {
                    entityDefinition.indexes = [];
                }
                var indexColumns = indexCandidates.get(key);
                Sys.println('entities    >   creating index for fields: ${indexColumns.join(", ")}');
                entityDefinition.indexes.push(indexColumns);
            }

            for (v in entityClass.varsAndProps) {
                if (v.isStatic) {
                    continue;
                }

                var fieldName = v.name;
                var fieldOptions:Array<EntityFieldOption> = v.entityFieldOptions();
                if (fieldOptions.contains(Ignore)) {
                    continue;
                }

                var complexType = TypeTools.toComplexType(Context.followWithAbstracts(ComplexTypeTools.toType(v.complexType)));
                switch (complexType) {
                    case (macro: Bool)  | (macro: Null<Bool>)  | (macro: StdTypes.Bool):
                        if (!(v is ClassProperty)) { // we'll only allow primitives to be var, and will assume properties are helpers (may be ill conceived)
                            entityDefinition.fields.push({ name: fieldName, options: fieldOptions, type: EntityFieldType.Boolean });
                        }
                    case (macro: Int)   | (macro: Null<Int>)   | (macro: StdTypes.Int):
                        if (!(v is ClassProperty)) { // we'll only allow primitives to be var, and will assume properties are helpers (may be ill conceived)
                            entityDefinition.fields.push({ name: fieldName, options: fieldOptions, type: EntityFieldType.Number });
                        }
                    case (macro: Float) | (macro: Null<Float>) | (macro: StdTypes.Float):
                        if (!(v is ClassProperty)) { // we'll only allow primitives to be var, and will assume properties are helpers (may be ill conceived)
                            entityDefinition.fields.push({ name: fieldName, options: fieldOptions, type: EntityFieldType.Decimal });
                        }
                    case (macro: String):
                        if (!(v is ClassProperty)) { // we'll only allow primitives to be var, and will assume properties are helpers (may be ill conceived)
                            var size = v.metadata.paramAsInt(EntityMetadata.Size);
                            if (size == null) { // if no @:size meta is present, we'll default to -1, which for strings will mean a memo db column (unlimited size)
                                size = EntityManager.DefaultFieldSize;
                            }
                            var sizeTruncateString = v.metadata.paramAsString("size", 1);
                            if (sizeTruncateString != null && sizeTruncateString.toLowerCase() == EntityMetadata.Truncate && !fieldOptions.contains(EntityFieldOption.TruncateToSize)) {
                                fieldOptions.push(EntityFieldOption.TruncateToSize);
                            } else if (sizeTruncateString != null && sizeTruncateString.toLowerCase() == EntityMetadata.NoTruncate) {
                                fieldOptions.remove(EntityFieldOption.TruncateToSize);
                            }
                            entityDefinition.fields.push({ name: fieldName, options: fieldOptions, type: EntityFieldType.Text(size) });
                        }
                    case (macro: Date):
                        if (!(v is ClassProperty)) { // we'll only allow primitives to be var, and will assume properties are helpers (may be ill conceived)
                            entityDefinition.fields.push({ name: fieldName, options: fieldOptions, type: EntityFieldType.Date });
                        }
                    case (macro: Array<$valueComplexType>):
                        if (valueComplexType.isEntity()) {
                            var entityValueClass = new ClassBuilder(valueComplexType.toType());
                            if (entityValueClass.qualifiedName == entityClass.qualifiedName) {
                                entityValueClass = entityClass;
                            }
                            var entityValueFullClassName = valueComplexType.toType().toString();
                            entityDefinition.fields.push({
                                name: fieldName,
                                options: fieldOptions,
                                type: EntityFieldType.Entity(
                                    entityValueClass.qualifiedName,
                                    EntityFieldRelationship.OneToMany(
                                        entityClass.tableName(), entityClass.primaryKeyFieldName(),
                                        entityValueClass.tableName(), entityValueClass.primaryKeyFieldName()
                                    ),
                                    EntityFieldType.Number
                                )
                            });
                        } else {
                            var primitiveType = null;
                            switch (valueComplexType) {
                                case (macro: Bool)  | (macro: Null<Bool>)   | (macro: StdTypes.Bool):
                                    primitiveType = "Bool";
                                case (macro: Int)   | (macro: Null<Int>)    | (macro: StdTypes.Int):    
                                    primitiveType = "Int";
                                case (macro: Float) | (macro: Null<Float>) | (macro: StdTypes.Float):
                                    primitiveType = "Float";
                                case (macro: String):
                                    primitiveType = "String";
                                case (macro: Date):
                                    primitiveType = "Date";
                                case _:
                                    trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> ", valueComplexType);
                            }
                            var valueComplexType = TPath(primitiveType.primitiveEntityTypePathFromType());
                            var entityValueClass = new ClassBuilder(valueComplexType.toType());
                            if (entityValueClass.qualifiedName == entityClass.qualifiedName) {
                                entityValueClass = entityClass;
                            }
                            // primitive arrays should cascade deletions _always_
                            if (!fieldOptions.contains(EntityFieldOption.CascadeDeletions)) {
                                fieldOptions.push(EntityFieldOption.CascadeDeletions);
                            }
                            var entityValueFullClassName = valueComplexType.toType().toString();
                            entityDefinition.fields.push({
                                name: fieldName,
                                options: fieldOptions,
                                type: EntityFieldType.Entity(
                                    entityValueClass.qualifiedName,
                                    EntityFieldRelationship.OneToMany(
                                        entityClass.tableName(), entityClass.primaryKeyFieldName(),
                                        entityValueClass.tableName(), entityValueClass.primaryKeyFieldName()
                                    ),
                                    EntityFieldType.Number
                                ),
                                primitive: true,
                                primitiveType: primitiveType
                            });
                            var entityVar = entityClass.addVar("_" + fieldName + "Entities", macro: Array<$valueComplexType>, macro null, [APrivate]);
                            entityVar.metadata.add(":noCompletion");
                        }
                    case (macro: Map<$keyComplexType, $valueComplexType>):
                    case (macro: $valueComplexType):
                        if (valueComplexType.isEntity()) {
                            v.remove();
                            var hadExistingSetter = entityClass.hasPropSetter(v.name);
                            var entityVarName = "_" + v.name;
                            var entityVar = entityClass.findOrCreateVar(entityVarName, v.complexType, [APrivate]);
                            entityVar.metadata.add(":noCompletion");
                            var entityProp = entityClass.findOrCreateProperty(v.name, v.complexType, v.access, "get", "set");
                            var entityGetter = entityProp.findOrCreateGetter();
                            var entitySetter = entityProp.findOrCreateSetter();

                            // this will remove any assignments in the original setter, so, for example
                            // `_someVar = value` will be removed from the original expr since entities
                            // wants to control that assignment
                            var findAssignments = null;
                            findAssignments = (expr) -> {
                                return switch (expr.expr) {
                                    case EBinop(OpAssign, e1, e2):
                                        var removeExpr = switch (e1.expr) {
                                            case EConst(CIdent(s)): (s == entityVarName || s == v.name);
                                            case _:                 false;  
                                        }
                                        if (removeExpr) {
                                            macro {};
                                        } else {
                                            ExprTools.map(expr, findAssignments);
                                        }
                                    case _:    
                                        ExprTools.map(expr, findAssignments);
                                }
                            }
                            entitySetter.expr = ExprTools.map(entitySetter.code.expr, findAssignments);

                            entityGetter.code += macro {
                                return $i{entityVarName};
                            }

                            // the only difference between these go generated code blocks in the "return value"
                            // if the return existed on an existing setter, then it would effectively "cut off"
                            // the rest of the code that already existed in the setter, it would be possible
                            // to just add the duplicated code and then append an "return value" only but
                            // at least for now, this is clearer
                            if (hadExistingSetter) {
                                entitySetter.code.add(macro @:privateAccess {
                                    if ($i{entityVarName} == null || value == null) {
                                        $i{entityVarName} = value;
                                    } else if (value.primaryKeyValue() != null && $i{entityVarName}.primaryKeyValue() != value.primaryKeyValue()) {
                                        $i{entityVarName} = value;
                                    } else {
                                        @:privateAccess $i{entityVarName}.copyFrom(value);
                                    }
                                    //return value;
                                }, null, Start);
                            } else {
                                entitySetter.code.add(macro @:privateAccess {
                                    if ($i{entityVarName} == null || value == null) {
                                        $i{entityVarName} = value;
                                    } else if (value.primaryKeyValue() != null && $i{entityVarName}.primaryKeyValue() != value.primaryKeyValue()) {
                                        $i{entityVarName} = value;
                                    } else {
                                        @:privateAccess $i{entityVarName}.copyFrom(value);
                                    }
                                    return value;
                                }, null, Start);
                            }

                            var entityValueClass = new ClassBuilder(valueComplexType.toType());
                            if (entityValueClass.qualifiedName == entityClass.qualifiedName) {
                                entityValueClass = entityClass;
                            }
                            entityDefinition.fields.push({
                                name: fieldName,
                                options: fieldOptions,
                                type: EntityFieldType.Entity(
                                    entityValueClass.qualifiedName,
                                    EntityFieldRelationship.OneToOne(
                                        entityClass.tableName(), entityClass.primaryKeyFieldName(),
                                        entityValueClass.tableName(), entityValueClass.primaryKeyFieldName()
                                    ),
                                    EntityFieldType.Number
                                )
                            });
                        } else {
                            trace(">>>>>>>>>>>>>>>>>>>>>>>>>>>> its NOT an entity", entityClass.qualifiedName, fieldName, complexType, Context.followWithAbstracts(ComplexTypeTools.toType(valueComplexType)));
                        }
                }
                //Sys.println("entities    >    " + v.name);
            }
        }

        if (!entityClass.isExtern) {
            buildEntityDefinitionFields(entityClass, entityDefinition);
            buildTableSchemaFields(entityClass, entityDefinition);
            buildInit(entityClass, entityDefinition);
            buildCheckTables(entityClass, entityDefinition);
            buildCheckIndexes(entityClass, entityDefinition);
        }

        buildFieldSets(entityClass, entityDefinition);

        if (!entityClass.isExtern) {
            buildToRecord(entityClass, entityDefinition);
            buildFromRecord(entityClass, entityDefinition);
        }
        
        buildAdd(entityClass, entityDefinition);
        if (!entityClass.isExtern) {
            buildAddData(entityClass, entityDefinition);
            buildAddJoinData(entityClass, entityDefinition);
        }

        buildDelete(entityClass, entityDefinition);
        if (!entityClass.isExtern) {
            buildDeleteData(entityClass, entityDefinition);
            buildDeleteJoinData(entityClass, entityDefinition);
        }
        buildDeleteById(entityClass, entityDefinition);

        buildUpdate(entityClass, entityDefinition);
        if (!entityClass.isExtern) {
            buildUpdateData(entityClass, entityDefinition);
            buildUpdateJoinData(entityClass, entityDefinition);
        }

        if (!entityClass.isExtern) {
            buildFindInternal(entityClass, entityDefinition);
            buildFindUniqueInternal(entityClass, entityDefinition);
            buildCopyFrom(entityClass, entityDefinition);
        }
        buildFind(entityClass, entityDefinition);
        buildFindById(entityClass, entityDefinition);
        buildFindByPage(entityClass, entityDefinition);
        buildFindAll(entityClass, entityDefinition);
        buildCount(entityClass, entityDefinition);

        buildFindUnique(entityClass, entityDefinition);
        
        buildRefresh(entityClass, entityDefinition);

        return entityClass.fields;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Misc
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    public static function buildEntityDefinitionFields(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        entityClass.addStaticVar("EntityDefinition", macro: entities.EntityDefinition, macro $v{entityDefinition}, [APrivate]);

        var primaryKeyQueryFn = entityClass.addStaticFunction("primaryKeyQuery", [
            {name: "primaryKey", type: macro: Null<Int>}
        ], macro: Query.QueryExpr, [APrivate]);
        primaryKeyQueryFn.code += macro {
            var q = Query.query(Query.field($v{primaryKeyName}) = primaryKey);
            return q;
        }

        var primaryKeysQueryFn = entityClass.addStaticFunction("primaryKeysQuery", [
            {name: "primaryKeys", type: macro: Array<Int>}
        ], macro: Query.QueryExpr, [APrivate]);
        primaryKeysQueryFn.code += macro {
            var q = Query.query(Query.field($v{primaryKeyName}) in primaryKeys);
            return q;
        }

        var primaryKeyValueFn = entityClass.addFunction("primaryKeyValue", macro: Null<Int>, [APrivate]);
        primaryKeyValueFn.code += macro {
            return $i{primaryKeyName};
        }

    }

    static function buildTableSchemaFields(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        entityClass.addStaticVar("TableSchema", macro: db.TableSchema, macro entities.EntityDefinitionTools.toTableSchema(EntityDefinition), [APrivate]);

        var associationTableSchemas = [];
        for (field in entityDefinition.fields) {
            switch (field.type) {
                case Unknown | Boolean | Number | Decimal | Text(_) | Date | Binary:
                    // do nothing, dont want to use "case _:" so future enum additions will be flagged and handled explicitly
                case Entity(className, relationship, type):
                    switch (relationship) {
                        case OneToOne(table1, field1, table2, field2):
                            // do nothing, dont want to use "case _:" so future enum additions will be flagged and handled explicitly
                        case OneToMany(table1, field1, table2, field2):
                            var associationTableSchema:TableSchema = {
                                name: table1 + "_" + field.name,
                                columns: [
                                    {name: field1, type: type.toColumnType()},
                                    {name: field.name + "_" + field2, type: type.toColumnType()}
                                ]
                            };
                            associationTableSchemas.push(associationTableSchema.toTableSchemaExpr());
                    }
            }
        }
        entityClass.addStaticVar("JoinTableSchemas", macro: Array<db.TableSchema>, macro $a{associationTableSchemas}, [APrivate]);
    }

    static function buildInit(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        entityClass.addStaticVar("_init", macro: Bool, macro false, [APrivate]);
        var initFn = entityClass.addStaticFunction("init", macro: promises.Promise<Bool>, [APrivate]);

        initFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                if (_init) {
                    resolve(true);
                } else {
                    _init = true;
                    entities.EntityManager.instance.connect().then(success -> {
                        return checkTables();
                    }).then(result -> {
                        return checkIndexes();
                    }).then(result -> {
                        resolve(true);
                    }, error -> {
                        reject(error);
                    });
                }
            });
        }

        var __init__Fn = entityClass.addStaticFunction("__init__", null, [APrivate]);
        __init__Fn.code += macro @:privateAccess {
            entities.EntityManager.instance.registerEntityInit(init);
        }
    }

    public static function buildCheckTables(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var checkTablesFn = entityClass.addStaticFunction("checkTables", macro: promises.Promise<Bool>, [APrivate]);
        checkTablesFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                var promiseList = [];
                promiseList.push(entities.EntityManager.instance.checkTableSchema.bind(TableSchema));
                for (joinTableSchema in JoinTableSchemas) {
                    promiseList.push(entities.EntityManager.instance.checkTableSchema.bind(joinTableSchema));
                }
                promises.PromiseUtils.runSequentially(promiseList).then(_ -> {
                    resolve(true);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    public static function buildCheckIndexes(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var checkIndexesFn = entityClass.addStaticFunction("checkIndexes", macro: promises.Promise<Bool>, [APrivate]);
        checkIndexesFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                var promiseList = [];
                $b{[for (columnList in entityDefinition.indexes) {
                    macro {
                        promiseList.push(entities.EntityManager.instance.createIndex.bind(TableSchema.name, $v{columnList}));
                    }
                }]}

                promises.PromiseUtils.runSequentially(promiseList).then(_ -> {
                    resolve(true);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    public static function buildFieldSets(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var fieldSetsMetaList = entityClass.metadata.list("fieldset");
        for (item in fieldSetsMetaList) {
            var finalValues:Array<String> = [];
            var name = ExprTools.toString(item.params[0]);
            var values = item.params[1];
            switch (values.expr) {
                case EArrayDecl(values):
                    for (value in values) {
                        finalValues.push(ExprTools.toString(value));
                    }
                case _:    
            }

            if (!entityClass.isExtern) {
                entityClass.addStaticVar(name, macro: entities.EntityFieldSet, macro new entities.EntityFieldSet($v{finalValues}), [AFinal]);
            } else {
                entityClass.addStaticVar(name, macro: entities.EntityFieldSet, null, [AFinal]);
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Record
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    static function buildToRecord(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var toRecordFn = entityClass.addFunction("toRecord", [
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: db.Record, [APrivate]);
        toRecordFn.metadata.add(":noCompletion");

        toRecordFn.code += macro @:privateAccess {
            var record = new db.Record();
            $b{[for (entityField in entityDefinition.primitiveFields()) {
                macro {
                    record.field($v{entityField.name}, entities.EntityManager.instance.convertPrimitiveToDB($i{entityField.name}, $v{entityField.type}, $v{entityField.options}));
                }
            }]}
            $b{[for (entityField in entityDefinition.entityFields_OneToOne()) {
                var foreignKey = entityField.foreignKey();
                macro {
                    if ($i{entityField.name} != null) {
                        record.field($v{entityField.name}, $i{entityField.name}.$foreignKey);
                    }
                }
            }]}
            return record;
        }
    }

    static function buildFromRecord(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var fromRecordFn = entityClass.addFunction("fromRecord", [
            {name: "record", type: macro: db.Record},
            {name: "queryCacheId", type: macro: String},
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<$entityComplexType>, [APrivate]);
        fromRecordFn.metadata.add(":noCompletion");

        fromRecordFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    // primary key
                    this.$primaryKeyName = record.field($v{primaryKeyName});
                    // primitives
                    $b{[for (entityField in entityDefinition.primitiveFields()) {
                        if (entityField.name == primaryKeyName) {
                            continue;
                        }
                        macro {
                            if (fieldSet.allow($v{entityField.name})) {
                                $i{entityField.name} = entities.EntityManager.instance.convertPrimitiveFromDB(record.field($v{entityField.name}), $v{entityField.type});
                            }
                        }
                    }]}

                    var promiseList:Array<() -> promises.Promise<Any>> = [];

                    // one to one
                    $b{[for (entityField in entityDefinition.entityFields_OneToOne()) {
                        var classDef = entityField.toClassDefExpr(entityDefinition);
                        macro {
                            if (fieldSet.allow($v{entityField.name})) {
                                var id = record.field($v{entityField.name});
                                if (id != null) {
                                    promiseList.push(() -> {
                                        return new promises.Promise((resolve, reject) -> {
                                            $p{classDef}.findInternal($p{classDef}.primaryKeyQuery(id), queryCacheId, fieldSet).then(entities -> {
                                                $i{entityField.name} = entities[0];
                                                resolve(true);
                                            }, error -> {
                                                reject(error);
                                            });
                                        }); 
                                    });
                                }
                            }
                        }
                    }]}
                    // one to many
                    $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                        var fieldName = entityField.name;
                        if (entityField.primitive) {
                            fieldName = entityField.primitiveEntityFieldName();
                        }
                        var joinTableName = entityField.joinTableName();
                        var joinForeignKey = entityField.joinForeignKey();
                        var classDef = entityField.toClassDefExpr(entityDefinition);
                        macro {
                            if (fieldSet.allow($v{entityField.name}) && $i{primaryKeyName} != null) {
                                promiseList.push(() -> {
                                    return new promises.Promise((resolve, reject) -> {
                                        entities.EntityManager.instance.find($v{joinTableName}, primaryKeyQuery($i{primaryKeyName}), queryCacheId).then(result -> {
                                            var ids = result.extractFieldValues($v{joinForeignKey});
                                            if (ids.length == 0) {
                                                return null;
                                            }
                                            return $p{classDef}.findInternal($p{classDef}.primaryKeysQuery(ids), queryCacheId, fieldSet);
                                        }).then(entities -> {
                                            if (entities != null) {
                                                $i{fieldName} = entities;
                                                ${if (entityField.primitive) {
                                                    macro {
                                                        $i{entityField.name} = [];
                                                        for (item in entities) {
                                                            $i{entityField.name}.push(item.value);
                                                        }
                                                    };
                                                } else {
                                                    macro null;
                                                }}
                                            } else {
                                                $i{fieldName} = [];
                                                ${if (entityField.primitive) {
                                                    macro {
                                                        $i{entityField.name} = [];
                                                    };
                                                } else {
                                                    macro null;
                                                }}
                                            }
                                            resolve(true);
                                        }, error -> {
                                            reject(error);
                                        });
                                    });
                                });
                            }
                        }
                    }]}

                    return promises.PromiseUtils.runSequentially(promiseList);
                }).then(result -> {
                    resolve(this);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Add
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    static function buildAdd(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var addFn = entityClass.addFunction("add", [
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<$entityComplexType>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        addFn.code += macro @:privateAccess {
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            if ($i{primaryKeyName} != null) {
                return update(fieldSet);
            } else {
                return new promises.Promise((resolve, reject) -> {
                    init().then(_ -> {
                        var promiseList:Array<() -> promises.Promise<Any>> = [];
                        // one to one
                        $b{[for (entityField in entityDefinition.entityFields_OneToOne()) {
                            var foreignKey = entityField.foreignKey();
                            macro {
                                if ($i{entityField.name} != null) {
                                    if ($i{entityField.name}.$foreignKey == null) {
                                        promiseList.push($i{entityField.name}.add.bind(fieldSet));
                                    } else {
                                        promiseList.push($i{entityField.name}.update.bind(fieldSet));
                                    }
                                }
                            }
                        }]}
                        // one to many
                        $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                            var fieldName = entityField.name;
                            if (entityField.primitive) {
                                fieldName = entityField.primitiveEntityFieldName();
                            }
                            var foreignKey = entityField.foreignKey();
                            macro {
                                ${if (entityField.primitive) {
                                    var primitiveEntityClassComplexType = entityField.primitiveEntityTypePath();
                                    macro {
                                        if ($i{entityField.name} != null) {
                                            $i{fieldName} = [];
                                            for (item in $i{entityField.name}) {
                                                $i{fieldName}.push(new $primitiveEntityClassComplexType(item));
                                            }
                                        }
                                    };
                                } else {
                                    macro null;
                                }}

                                if ($i{fieldName} != null) {
                                    for (item in $i{fieldName}) {
                                        if (item.$foreignKey == null) {
                                            promiseList.push(item.add.bind(fieldSet));
                                        } else {
                                            promiseList.push(item.update.bind(fieldSet));
                                        }
                                    }
                                }
                            }
                        }]}
                        return promises.PromiseUtils.runSequentially(promiseList);
                    }).then(result -> {
                        return addData(fieldSet);
                    }).then(result -> {
                        resolve(this);
                    }, error -> {
                        reject(error);
                    });
                });            
            }
        }
    }

    static function buildAddData(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var entityTableName = entityDefinition.tableName;
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var addDataFn = entityClass.addFunction("addData", [
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<$entityComplexType>, [APrivate]);
        addDataFn.metadata.add(":noCompletion");

        addDataFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                var record = this.toRecord(fieldSet);
                init().then(_ -> {
                    return entities.EntityManager.instance.addRecord($v{entityTableName}, record);
                }).then(result -> {
                    this.$primaryKeyName = result.field("_insertedId");
                    return addJoinData(fieldSet);
                }).then(result -> {
                    resolve(this);
                }, error -> {
                    reject(error);
                });
            });
        }

    }

    static function buildAddJoinData(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var primaryKeyField = entityDefinition.primaryKeyFieldName;

        var addJoinDataFn = entityClass.addFunction("addJoinData", [
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<Bool>, [APrivate]);
        addJoinDataFn.metadata.add(":noCompletion");

        addJoinDataFn.code += macro {
            return new promises.Promise((resolve, reject) -> @:privateAccess {
                init().then(_ -> {
                    var promiseList = [];

                    $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                        var fieldName = entityField.name;
                        if (entityField.primitive) {
                            fieldName = entityField.primitiveEntityFieldName();
                        }
                        var joinForeignKey = entityField.joinForeignKey();
                        var foreignKey = entityField.foreignKey();
                        macro {
                            promiseList.push(() -> {
                                return new promises.Promise((resolve, reject) -> {
                                    var joinRecords = new Array<db.Record>();
                                    if ($i{fieldName} != null) {
                                        for (item in $i{fieldName}) {
                                            var joinRecord = new db.Record();
                                            joinRecord.field($v{primaryKeyField}, $i{primaryKeyField});
                                            joinRecord.field($v{joinForeignKey}, item.$foreignKey);
                                            joinRecords.push(joinRecord);
                                        }
                                    }
                                    entities.EntityManager.instance.addRecords($v{entityField.joinTableName()}, joinRecords).then(_ -> {
                                        resolve(true);
                                    }, error -> {
                                        reject(error);
                                    });
                                });
                            });
                        }
                    }]}
                    
                    return promises.PromiseUtils.runSequentially(promiseList);
                }).then(result -> {
                    resolve(true);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Delete
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    static function buildDelete(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var addFn = entityClass.addFunction("delete", [
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<$entityComplexType>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        addFn.code += macro {
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            return new promises.Promise((resolve, reject) -> {
                var entityInDB:$entityComplexType = null;
                init().then(_ -> {
                    return findById(this.$primaryKeyName);
                }).then(result -> {
                    entityInDB = result;
                    var promiseList:Array<() -> promises.Promise<Any>> = [];
                    // one to one
                    $b{[for (entityField in entityDefinition.entityFields_OneToOne()) {
                        var cascadeDeletions = entityField.cascadeDeletions();
                        if (!cascadeDeletions) {
                            continue;
                        }
                        macro {
                            if ($i{entityField.name} != null) {
                                promiseList.push($i{entityField.name}.delete.bind(fieldSet));
                            }
                        }
                    }]}
                    // one to many
                    $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                        var cascadeDeletions = entityField.cascadeDeletions();
                        if (!cascadeDeletions) {
                            continue;
                        }
                        var fieldName = entityField.name;
                        if (entityField.primitive) {
                            fieldName = entityField.primitiveEntityFieldName();
                        }
                        macro {
                            if ($i{fieldName} != null) {
                                for (item in $i{fieldName}) {
                                    promiseList.push(item.delete.bind(fieldSet));
                                }
                            }
                        }
                    }]}
                    return promises.PromiseUtils.runSequentially(promiseList);
                }).then(result -> {
                    return deleteData(entityInDB, fieldSet);
                }).then(result -> {
                    resolve(this);
                }, error -> {
                    reject(error);
                });
            });            
        }
    }

    static function buildDeleteData(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var entityTableName = entityDefinition.tableName;
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var deleteDataDataFn = entityClass.addFunction("deleteData", [
            {name: "entityInDB", type: macro: $entityComplexType},
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<$entityComplexType>, [APrivate]);
        deleteDataDataFn.metadata.add(":noCompletion");

        deleteDataDataFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return entities.EntityManager.instance.deleteAll($v{entityTableName}, primaryKeyQuery($i{primaryKeyName}));
                }).then(result -> {
                    return deleteJoinData(entityInDB, fieldSet);
                }).then(result -> {
                    resolve(this);
                }, error -> {
                    reject(error);
                });
            });
        }

    }

    static function buildDeleteJoinData(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyField = entityDefinition.primaryKeyFieldName;

        var deleteJoinDataFn = entityClass.addFunction("deleteJoinData", [
            {name: "entityInDB", type: macro: $entityComplexType},
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<Bool>, [APrivate]);
        deleteJoinDataFn.metadata.add(":noCompletion");

        deleteJoinDataFn.code += macro {
            return new promises.Promise((resolve, reject) -> @:privateAccess {
                init().then(_ -> {
                    var promiseList:Array<() -> promises.Promise<Any>> = [];
                    // one to many
                    $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                        var fieldName = entityField.name;
                        if (entityField.primitive) {
                            fieldName = entityField.primitiveEntityFieldName();
                        }
                        var foreignKey = entityField.foreignKey();
                        var joinForeignKey = entityField.joinForeignKey();
                        var joinTableName = entityField.joinTableName();
                        macro {
                            if ($i{fieldName} != null && entityInDB != null && entityInDB.$fieldName != null) {
                                var idsInDB = entityInDB.$fieldName.map(item -> item.$foreignKey);
                                if (idsInDB.length > 0) {
                                    var query = Query.query(Query.field($v{primaryKeyField}) = this.$primaryKeyField && Query.field($v{joinForeignKey}) in idsInDB);
                                    promiseList.push(entities.EntityManager.instance.deleteAll.bind($v{joinTableName}, query));
                                }
                            }
                        }
                    }]}
                    return promises.PromiseUtils.runSequentially(promiseList);
                }).then(result -> {
                    resolve(true);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    static function buildDeleteById(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyField = entityDefinition.primaryKeyFieldName;

        var deleteJoinDataFn = entityClass.addStaticFunction("deleteById", [
            {name: "id", type: macro: Null<Int>},
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<Bool>, [APrivate]);
        if (entityClass.isExtern) {
            return;
        }

        deleteJoinDataFn.code += macro {
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            return new promises.Promise((resolve, reject) -> @:privateAccess {
                init().then(_ -> {
                    return findById(id);
                }).then(result -> {
                    return result.delete(fieldSet);
                }).then(result -> {
                    resolve(true);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Update
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    static function buildUpdate(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var updateFn = entityClass.addFunction("update", [
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<$entityComplexType>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        updateFn.code += macro @:privateAccess {
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            if ($i{primaryKeyName} == null) {
                return add(fieldSet);
            } else {
                return new promises.Promise((resolve, reject) -> {
                    var entityInDB:$entityComplexType = null;
                    init().then(_ -> {
                        return findById(this.$primaryKeyName);
                    }).then(result -> {
                        entityInDB = result;
                        var promiseList:Array<() -> promises.Promise<Any>> = [];
                        // one to one
                        $b{[for (entityField in entityDefinition.entityFields_OneToOne()) {
                            var foreignKey = entityField.foreignKey();
                            var mustExist:Bool = entityField.mustExist();
                            /* MAY NEED THIS STILL
                            var prevRefVarName = "_" + entityField.name + "PrevRef";
                            var cascadeDeletions = entityField.cascadeDeletions();
                            */
                            macro {
                                ${if (mustExist) {
                                    macro {
                                        if ($i{entityField.name} != null && $i{entityField.name}.$foreignKey == null) {
                                            reject("property '" + $v{entityField.name} + "' in entity '" + $v{entityClass.name} + "' must already exist in the database, no primary key found on object (" + $v{foreignKey} + ")");
                                            return null;
                                        }
                                    }
                                } else {
                                    macro null;
                                }}

                                /* MAY NEED THIS STILL
                                ${if (cascadeDeletions) {
                                    macro {
                                        if ($i{prevRefVarName} != null && $i{prevRefVarName}.$foreignKey != $i{entityField.name}.$foreignKey) {
                                            promiseList.push($i{prevRefVarName}.delete.bind());
                                            $i{prevRefVarName} = null;
                                        }
                                    };
                                } else {
                                    macro null;
                                }}
                                */    

                                if ($i{entityField.name} != null) {
                                    if ($i{entityField.name}.$foreignKey == null) {
                                        promiseList.push($i{entityField.name}.add.bind(fieldSet));
                                    } else {
                                        promiseList.push($i{entityField.name}.update.bind(fieldSet));
                                    }
                                }
                            }
                        }]}
                        // one to many
                        $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                            var fieldName = entityField.name;
                            if (entityField.primitive) {
                                fieldName = entityField.primitiveEntityFieldName();
                            }
                            var foreignKey = entityField.foreignKey();
                            var mustExist:Bool = entityField.mustExist();
                            macro {
                                ${if (mustExist) {
                                    macro {
                                        if ($i{fieldName} != null) {
                                            for (item in $i{fieldName}) {
                                                if (item.$foreignKey == null) {
                                                    reject("property items in '" + $v{entityField.name} + "' in entity '" + $v{entityClass.name} + "' must already exist in the database, no primary key found on object (" + $v{foreignKey} + ")");
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    macro null;
                                }}

                                ${if (entityField.primitive) {
                                    var primitiveEntityClassComplexType = entityField.primitiveEntityTypePath();
                                    macro {
                                        if ($i{entityField.name} != null) {
                                            if ($i{fieldName} == null) {
                                                $i{fieldName} = [];
                                            }
                                            while ($i{fieldName}.length > $i{entityField.name}.length) {
                                                $i{fieldName}.pop();
                                            }
                                            while ($i{fieldName}.length != $i{entityField.name}.length) {
                                                $i{fieldName}.push(new $primitiveEntityClassComplexType());
                                            }
                                            //var diff1 
                                            for (i in 0...$i{entityField.name}.length) {
                                                $i{fieldName}[i].value = $i{entityField.name}[i];
                                            }
                                        }
                                    };
                                } else {
                                    macro null;
                                }}

                                if ($i{fieldName} != null) {
                                    for (item in $i{fieldName}) {
                                        if (item.$foreignKey == null) {
                                            promiseList.push(item.add.bind(fieldSet));
                                        } else {
                                            promiseList.push(item.update.bind(fieldSet));
                                        }
                                    }
                                }
                            }
                        }]}
                        return promises.PromiseUtils.runSequentially(promiseList);
                    }).then(result -> {
                        return updateData(entityInDB, fieldSet);
                    }).then(result -> {
                        resolve(this);
                    }, error -> {
                        reject(error);
                    });
                });            
            }
        }
    }

    static function buildUpdateData(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var entityTableName = entityDefinition.tableName;
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var updateDataFn = entityClass.addFunction("updateData", [
            {name: "entityInDB", type: macro: $entityComplexType},
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<$entityComplexType>, [APrivate]);
        updateDataFn.metadata.add(":noCompletion");

        updateDataFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                var record = toRecord(fieldSet);
                init().then(_ -> {
                    entities.EntityManager.instance.updateRecord($v{entityTableName}, primaryKeyQuery($i{primaryKeyName}), record);
                }).then(result -> {
                    return updateJoinData(entityInDB, fieldSet);
                }).then(result -> {
                    resolve(this);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    static function buildUpdateJoinData(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyField = entityDefinition.primaryKeyFieldName;

        var updateJoinDataFn = entityClass.addFunction("updateJoinData", [
            {name: "entityInDB", type: macro: $entityComplexType},
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<Bool>, [APrivate]);
        updateJoinDataFn.metadata.add(":noCompletion");

        updateJoinDataFn.code += macro {
            return new promises.Promise((resolve, reject) -> @:privateAccess {
                init().then(_ -> {
                    var promiseList:Array<() -> promises.Promise<Any>> = [];
                    // one to many
                    $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                        var cascadeDeletions = entityField.cascadeDeletions();
                        var fieldName = entityField.name;
                        if (entityField.primitive) {
                            fieldName = entityField.primitiveEntityFieldName();
                        }
                        var foreignKey = entityField.foreignKey();
                        var classDef = entityField.toClassDefExpr(entityDefinition);
                        var joinTableName = entityField.joinTableName();
                        var joinForeignKey = entityField.joinForeignKey();
                        macro {
                            if ($i{fieldName} != null) {
                                var diff = entities.EntityManager.instance.diffIds(
                                    entityInDB.$fieldName.map(item -> item.$foreignKey),
                                    this.$fieldName.map(item -> item.$foreignKey)
                                );

                                if (diff.idsToRemove.length > 0) {
                                    for (id in diff.idsToRemove) {
                                        if ($v{cascadeDeletions}) {
                                            promiseList.push($p{classDef}.deleteById.bind(id));
                                        }
                                        // we always want to delete the joins
                                        var query = Query.query(Query.field($v{primaryKeyField}) = this.$primaryKeyField && Query.field($v{joinForeignKey}) in diff.idsToRemove);
                                        promiseList.push(entities.EntityManager.instance.deleteAll.bind($v{joinTableName}, query));
                                    }
                                }

                                if (diff.idsToAdd.length > 0) {
                                    var joinRecords:Array<db.Record> = [];
                                    for (id in diff.idsToAdd) {
                                        var joinRecord = new db.Record();
                                        joinRecord.field($v{primaryKeyField}, this.$primaryKeyField);
                                        joinRecord.field($v{joinForeignKey}, id);
                                        joinRecords.push(joinRecord);
                                    }
                                    promiseList.push(entities.EntityManager.instance.addRecords.bind($v{joinTableName}, joinRecords));
                                }
                            }
                        }
                    }]}
                    return promises.PromiseUtils.runSequentially(promiseList);
                }).then(result -> {
                    resolve(true);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    static function buildCopyFrom(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var entityPrimaryKeyFieldName = entityClass.primaryKeyFieldName();

        var copyFromFn = entityClass.addFunction("copyFrom", [
            {name: "other", type: macro: $entityComplexType},
        ], macro: Void, [APrivate]);

        copyFromFn.code += macro @:privateAccess {
            $b{[for (entityField in entityDefinition.primitiveFields()) {
                var entityVarName = entityField.name;
                macro {
                    ${if (entityField.name == entityPrimaryKeyFieldName) {
                        macro {
                            if (this.primaryKeyValue() == null) {
                                $i{entityVarName} = other.$entityVarName;
                            }
                        }
                    } else {
                        macro {
                            $i{entityVarName} = other.$entityVarName;
                        }
                    }}
                }
            }]}

            $b{[for (entityField in entityDefinition.entityFields_OneToOne()) {
                var entityVarName = entityField.name;
                macro {
                    $i{entityVarName} = other.$entityVarName;
                }
            }]}

            $b{[for (entityField in entityDefinition.entityFields_OneToMany()) {
                var entityVarName = entityField.name;
                if (entityField.name == entityPrimaryKeyFieldName) {
                    continue;
                }
                macro {
                    $i{entityVarName} = other.$entityVarName;
                }
            }]}
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // Queries
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////
    static function buildFindInternal(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var entityTypePath = entityClass.toTypePath();
        var tableName = entityDefinition.tableName;

        var findInternalFn = entityClass.addStaticFunction("findInternal", [
            {name: "query", type: macro: Query.QueryExpr},
            {name: "queryCacheId", type: macro: String},
            {name: "fieldSet", type: macro: entities.EntityFieldSet},
            {name: "pageIndex", type: macro: Null<Int>, value: macro null},
            {name: "pageSize", type: macro: Null<Int>, value: macro null}
        ], macro: promises.Promise<Array<$entityComplexType>>, [APrivate]);

        findInternalFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    if (pageSize != null) {
                        var finalPageIndex = 0;
                        if (pageIndex != null) {
                            finalPageIndex = pageIndex;
                        }
                        return entities.EntityManager.instance.findPage($v{tableName}, query, finalPageIndex, pageSize, queryCacheId);
                    }
                    return entities.EntityManager.instance.find($v{tableName}, query, queryCacheId);
                }).then(result -> {
                    var promisesList:Array<() -> promises.Promise<$entityComplexType>> = [];
                    for (record in result) {
                        var entity = new $entityTypePath();
                        promisesList.push(entity.fromRecord.bind(record, queryCacheId, fieldSet));
                    }
                    return promises.PromiseUtils.runSequentially(promisesList);
                }).then(entities -> {
                    resolve(entities);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    static function buildFindUniqueInternal(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var entityTypePath = entityClass.toTypePath();
        var tableName = entityDefinition.tableName;

        var findUniqueInternalFn = entityClass.addStaticFunction("findUniqueInternal", [
            {name: "fieldName", type: macro: String},
            {name: "query", type: macro: Query.QueryExpr},
            {name: "queryCacheId", type: macro: String},
            {name: "fieldSet", type: macro: entities.EntityFieldSet}
        ], macro: promises.Promise<Array<$entityComplexType>>, [APrivate]);

        findUniqueInternalFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return entities.EntityManager.instance.findUnique($v{tableName}, fieldName, query, queryCacheId);
                }).then(result -> {
                    var promisesList:Array<() -> promises.Promise<$entityComplexType>> = [];
                    for (record in result) {
                        var entity = new $entityTypePath();
                        promisesList.push(entity.fromRecord.bind(record, queryCacheId, fieldSet));
                    }
                    return promises.PromiseUtils.runSequentially(promisesList);
                }).then(entities -> {
                    resolve(entities);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    static function buildFindById(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();

        var findByIdFn = entityClass.addStaticFunction("findById", [
            {name: "id", type: macro: Null<Int>},
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<$entityComplexType>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        findByIdFn.code += macro @:privateAccess {
            var queryCacheId = entities.EntityManager.instance.generateQueryCachedId();
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return findInternal(primaryKeyQuery(id), queryCacheId, fieldSet, 1);
                }).then(entitiesList -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    resolve(entitiesList[0]);
                }, error -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    reject(error);
                });
            });
        }
    }

    static function buildFindByPage(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();

        var findByPageFn = entityClass.addStaticFunction("findByPage", [
            {name: "query", type: macro: Query.QueryExpr, value: macro null},
            {name: "pageIndex", type: macro: Null<Int>, value: macro 0},
            {name: "pageSize", type: macro: Null<Int>, value: macro 10},
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<Array<$entityComplexType>>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        findByPageFn.code += macro @:privateAccess {
            var queryCacheId = entities.EntityManager.instance.generateQueryCachedId();
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return findInternal(query, queryCacheId, fieldSet, pageIndex, pageSize);
                }).then(entitiesList -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    resolve(entitiesList);
                }, error -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    reject(error);
                });
            });
        }
    }

    static function buildFind(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();

        var findByIdFn = entityClass.addStaticFunction("find", [
            {name: "query", type: macro: Query.QueryExpr},
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<$entityComplexType>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        findByIdFn.code += macro @:privateAccess {
            var queryCacheId = entities.EntityManager.instance.generateQueryCachedId();
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return findInternal(query, queryCacheId, fieldSet, 1);
                }).then(entitiesList -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    resolve(entitiesList[0]);
                }, error -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    reject(error);
                });
            });
        }
    }

    static function buildFindUnique(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();

        var findUniqueFn = entityClass.addStaticFunction("findUnique", [
            {name: "fieldName", type: macro: String},
            {name: "query", type: macro: Query.QueryExpr, value: macro null},
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<Array<$entityComplexType>>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        findUniqueFn.code += macro @:privateAccess {
            var queryCacheId = entities.EntityManager.instance.generateQueryCachedId();
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return findUniqueInternal(fieldName, query, queryCacheId, fieldSet);
                }).then(entitiesList -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    resolve(entitiesList);
                }, error -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    reject(error);
                });
            });
        }
    }

    static function buildFindAll(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();

        var findAllFn = entityClass.addStaticFunction("findAll", [
            {name: "query", type: macro: Query.QueryExpr, value: macro null},
            {name: "maxResults", type: macro: Null<Int>, value: macro null},
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<Array<$entityComplexType>>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        findAllFn.code += macro @:privateAccess {
            var queryCacheId = entities.EntityManager.instance.generateQueryCachedId();
            if (fieldSet == null) fieldSet = new entities.EntityFieldSet();
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return findInternal(query, queryCacheId, fieldSet, null, maxResults);
                }).then(entitiesList -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    resolve(entitiesList);
                }, error -> {
                    entities.EntityManager.instance.clearQueryCache(queryCacheId);
                    reject(error);
                });
            });
        }
    }

    static function buildCount(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var tableName = entityDefinition.tableName;

        var countFn = entityClass.addStaticFunction("count", [
            {name: "query", type: macro: Query.QueryExpr, value: macro null}
        ], macro: promises.Promise<Int>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        countFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                init().then(_ -> {
                    return entities.EntityManager.instance.count($v{tableName}, query);
                }).then(count -> {
                    resolve(count);
                }, error -> {
                    reject(error);
                });
            });
        }
    }

    static function buildRefresh(entityClass:ClassBuilder, entityDefinition:EntityDefinition) {
        var entityComplexType = entityClass.toComplexType();
        var primaryKeyName = entityDefinition.primaryKeyFieldName;

        var refreshFn = entityClass.addFunction("refresh", [
            {name: "fieldSet", type: macro: entities.EntityFieldSet, value: macro null}
        ], macro: promises.Promise<$entityComplexType>, [APublic]);
        if (entityClass.isExtern) {
            return;
        }

        refreshFn.code += macro @:privateAccess {
            return new promises.Promise((resolve, reject) -> {
                if (this.$primaryKeyName == null) {
                    reject('no primary key value, cannot refresh entity data');
                } else {
                    init().then(_ -> {
                        return findById(this.$primaryKeyName, fieldSet);
                    }).then(foundEntity -> {
                        if (foundEntity == null) {
                            reject('could not refresh entity data, no entity found with id ' + this.$primaryKeyName);
                        } else {
                            this.copyFrom(foundEntity);
                            resolve(this);
                        }
                    }, error -> {
                        reject(error);
                    });
                }
            });
        }

    }
}

#end