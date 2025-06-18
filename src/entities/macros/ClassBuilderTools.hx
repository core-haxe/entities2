package entities.macros;

#if macro

import entities.macros.helpers.ClassBuilder;
import entities.macros.helpers.ClassVariable;
import haxe.macro.Expr;
import haxe.macro.TypeTools;
import haxe.macro.ComplexTypeTools;
import haxe.macro.ExprTools;

using StringTools;

class ClassBuilderTools {
    public static function isEntity(classBuilder:ClassBuilder):Bool {
        return classBuilder.hasInterface("entities.IEntity");
    }

    public static function tableName(classBuilder:ClassBuilder, lowerCase:Bool = true) {
        var tableName = classBuilder.name;
        if (lowerCase) {
            tableName = tableName.toLowerCase();
        }
        if (classBuilder.metadata.contains("table")) {
            tableName = classBuilder.metadata.paramAsString("table");
        }
        return tableName;
    }

    public static function primaryKeyField(classBuilder:ClassBuilder):ClassVariable {
        if (classBuilder.metadata.contains("primaryKey")) {
            var primaryKeyName = classBuilder.metadata.paramAsString("primaryKey");
            var primaryKeyField = classBuilder.findVar(primaryKeyName);
            return primaryKeyField;
        }

        for (f in classBuilder.vars) {
            if (f.metadata.contains("primaryKey")) {
                return f;
            }
        }

        return null;
    }

    public static function buildIndexCandidates(classBuilder:ClassBuilder):Map<String, Array<String>> {    
        var indexMap:Map<String, Array<String>> = [];
        for (fn in classBuilder.functions) {
            if (!fn.metadata.contains("optimize")) {
                continue;
            }
            var columnArray = [];
            ExprTools.iter(fn.expr, findIndexCandidates.bind(columnArray));
            if (columnArray.length > 0) {
                for (columnNames in columnArray) {
                    var key = columnNames.join("_");
                    indexMap.set(key, columnNames);
                }
            }
        }
        return indexMap;
    }

    private static function findIndexCandidates(columnArray:Array<Array<String>>, e:Expr) {
        switch(e.expr) {
            case ECall({ expr: EField({ expr: EConst(CIdent("Query")) }, "query", Normal)}, params):
                var columnNames = [];
                for (p in params) {
                    ExprTools.iter(p, extractColumnNames.bind(columnNames));
                }
                if (columnNames.length != 0) {
                    columnArray.push(columnNames);
                }
            case _:
                ExprTools.iter(e, findIndexCandidates.bind(columnArray));
        }
    }

    private static function extractColumnNames(columnNames:Array<String>, e:Expr) {
        switch (e.expr) {
            case EConst(CIdent(s)):
                if (s.startsWith("$")) {
                    var columnName = s.substring(1);
                    if (!columnNames.contains(columnName)) {
                        columnNames.push(columnName);
                    }
                }
            case _:    
                ExprTools.iter(e, extractColumnNames.bind(columnNames));
        }
    }

    public static function substitutePrimaryKeysInQueryCalls(classBuilder:ClassBuilder) {
        for (fn in classBuilder.functions) {
            var isCandidate:Bool = false;
            var replacements:Map<String, String> = [];
            for (arg in fn.args) {
                if (arg.type == null) {
                    continue;
                }
                var typeString = ComplexTypeTools.toString(arg.type);
                if (typeString.startsWith("Class<")) { // little hacky but we want to skip Class<T> type args
                    continue;
                }
                if (!EntityComplexTypeTools.isEntity(arg.type)) {
                    continue;
                }
                isCandidate = true;
                var argType = new ClassBuilder(ComplexTypeTools.toType(arg.type));
                var primaryKeyName = primaryKeyFieldName(argType);
                replacements.set(arg.name, primaryKeyName);
            }

            if (!isCandidate) {
                continue;
            }

            fn.expr = ExprTools.map(fn.expr, replacePrimaryKeysInQueryCalls.bind(_, replacements));
        }
    }

    private static function replacePrimaryKeysInQueryCalls(e:Expr, replacements:Map<String, String>):Expr {
        return switch(e.expr) {
            case ECall({ expr: EField({ expr: EConst(CIdent("Query")) }, "query", Normal)}, params):
                ExprTools.map(e, handleReplacements.bind(_, replacements));   
            case _:
                ExprTools.map(e, replacePrimaryKeysInQueryCalls.bind(_, replacements));
        }
    }

    private static function handleReplacements(e:Expr, replacements:Map<String, String>):Expr {
        return switch(e.expr) {
            case EField({ expr: EConst(CIdent(c)) }, f, Normal):    
                e;
            case EConst(CIdent(s)):
                if (replacements.exists(s)) {
                    var varName = s;
                    var fieldName = replacements.get(s);
                    return macro $i{varName}.$fieldName;
                }
                e;
            case _:
                ExprTools.map(e, handleReplacements.bind(_, replacements));
        }
    }

    public static function primaryKeyFieldName(classBuilder:ClassBuilder):String {
        return autoGeneratedPrimaryKeyName(classBuilder);
    }

    public static function autoGeneratedPrimaryKeyName(classBuilder:ClassBuilder):String {
        var tableName = tableName(classBuilder, false);
        return tableName.substr(0, 1).toLowerCase() + tableName.substr(1) + "Id";
    }
}

#end