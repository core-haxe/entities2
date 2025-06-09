package;

abstract Timestamp(Float) to Float from Float {
	public static function now():Timestamp {
		return Date.now().getTime();
	}

	@:op(A + B) static function add(a:Timestamp, b:Timestamp):Timestamp;
	@:op(A - B) static function sub(a:Timestamp, b:Timestamp):Timestamp;
	@:op(A > B) static function gt(a:Timestamp, b:Timestamp):Bool;
	@:op(B < A) static function lt(a:Timestamp, b:Timestamp):Bool;
	@:op(A >= B) static function gte(a:Timestamp, b:Timestamp):Bool;
	@:op(B <= A) static function lte(a:Timestamp, b:Timestamp):Bool;
}
