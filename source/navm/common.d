module navm.common;

import navm.meta;

/// ByteCode version
public enum ushort NAVMBC_VERSION = 0x0004;

/// ByteCode
public struct Code{
	string[] labelNames; /// labelNames, index corresponds `labels`
	size_t[] labels; /// index in code for each label
	void[] code; /// instructions and their operands
	void[] data; /// data
}

/// Reads a void[] as a type
/// Returns: value in type T
package pragma(inline, true) inout(T) as(T)(inout void[] data) pure {
	assert(data.length >= T.sizeof);
	return *(cast(T*)data.ptr);
}

/// Returns: void[] against a value of type T
package pragma(inline, true) void[T.sizeof] asBytes(T)(T val) pure {
	void[T.sizeof] ret = (cast(void*)&val)[0 .. T.sizeof];
	return ret;
}

package bool isWhite(string s) pure {
	for (int i; i < s.length; i ++){
		if (s[i] != ' ' && s[i] != '\t')
			return false;
	}
	return true;
}

package ptrdiff_t indexOf(T)(T[] array, T needle) pure {
	for (ptrdiff_t i; i < array.length; i ++){
		if (array[i] == needle)
			return i;
	}
	return -1;
}

package bool canFind(T)(T[] array, T needle) pure {
	return array.indexOf(needle) != -1;
}

package bool isNum(string s, bool allowDecimalPoint=true) pure {
	bool hasDecimalPoint = false;
	if (!allowDecimalPoint)
		hasDecimalPoint = true; // hack
	if (s.length > 0 && s[0] == '-')
		s = s[1 .. $];
	if (s.length == 0)
		return false;
	foreach (c; s){
		if (c == '.' && !hasDecimalPoint){
			hasDecimalPoint = true;
		}else if (!"0123456789".canFind(c)){
			return false;
		}
	}
	return true;
}

package T parseInt(T)(string s) pure {
	if (s.length == 0)
		return T.init;
	import std.traits : isSigned;
	int multiplier = 1;
	static if (isSigned!T){
		if (s[0] == '-'){
			multiplier = -1;
			s = s[1 .. $];
		}
	}
	T r;
	for (ubyte i; i < s.length && i < ubyte.max; i ++)
		r = cast(T)(r * 10 + (s[i] - '0'));
	static if (isSigned!T)
		r *= multiplier;
	return r;
}

///
unittest{
	assert ("5".parseInt!int == 5);
	assert ("-5".parseInt!int == -5);
	assert ("55".parseInt!int == 55);
	assert ("-55".parseInt!int == -55);
}

package T parseFloat(T)(string s) pure {
	if (s.length == 0)
		return T.init;
	int multiplier = 1;
	if (s[0] == '-'){
		multiplier = -1;
		s = s[1 .. $];
	}
	T r = 0;
	for (ubyte i; i < s.length && i < ubyte.max; i ++){
		if (s[i] == '.'){
			r += cast(T)parseInt!size_t(s[i + 1 .. $]) /
				(10 * (cast(int)s.length - 1 - i));
			break;
		}
		r = (r * 10) + (s[i] - '0');
	}
	return r * multiplier;
}

///
unittest{
	assert ("5".parseFloat!float == 5);
	assert ("5.5".parseFloat!float == 5.5);
	assert ("-5".parseFloat!float == -5);
	assert ("-5.5".parseFloat!float == -5.5);
}

package bool isHexInt(string s) pure {
	for (ubyte i; i < s.length && i < ubyte.max; i ++){
		immutable char c = s[i];
		if ((c < '0' || c > '9') &&
				(c < 'a' || c > 'f') &&
				(c < 'A' || c > 'F'))
			return false;
	}
	return true;
}

///
unittest{
	assert ("123456789ABCDEFabcdef".isHexInt);
	assert ("ghixyz".isHexInt == false);
}

package size_t parseHexInt(string s) pure {
	size_t r = 0;
	for (ubyte i; i < s.length && i < ubyte.max; i ++){
		int c = s[i];
		if (c >= '0' && c <= '9'){
			r = (r * 16) + (c - '0');
			continue;
		}
		if (c >= 'a')
			c -= 32;
		r = (r * 16) + (c - 'A' + 10);
	}
	return r;
}

///
unittest{
	assert("0".parseHexInt == 0);
	assert("00".parseHexInt == 0);
	assert("1".parseHexInt == 1);
	assert("9".parseHexInt == 9);
	assert("A".parseHexInt == 0xA);
	assert("F".parseHexInt == 0xF);
	assert("A0".parseHexInt == 0xA0);
	assert("A9".parseHexInt == 0xA9);
	assert("AA".parseHexInt == 0xAA);
	assert("af".parseHexInt == 0xAF);
}

package bool isBinInt(string s) pure {
	for (ubyte i; i < s.length && i < ubyte.max; i ++){
		if (s[i] != '0' && s[i] != '1')
			return false;
	}
	return true;
}

///
unittest{
	assert ("010110".isBinInt);
	assert ("010110a".isBinInt == false);
}

package size_t parseBinInt(string s) pure {
	size_t r;
	for (ubyte i; i < s.length && i < ubyte.max; i ++){
		r <<= 1;
		if (s[i] == '1')
			r |= 1;
	}
	return r;
}

///
unittest{
	assert("0101".parseBinInt == 0B0101);
	assert("0".parseBinInt == 0);
	assert("1".parseBinInt == 1);
	assert("1101".parseBinInt == 0B1101);
}

package string intToStr(T)(T num){
	import core.stdc.math : log10, floor;
	if (num == 0)
		return "0";
	int isNegative = 0;
	if (num < 0){
		isNegative = 1;
		num *= -1;
	}
	immutable size_t len = cast(size_t)num.log10.floor + 1 + isNegative;
	char[] r = new char[len];
	int i = cast(int)r.length - 1;
	while (i >= isNegative){
		r[i] = cast(char)(num % 10 + '0');
		i --;
		num /= 10;
	}
	if (isNegative)
		r[0] = '-';
	return cast(string)r;
}

///
unittest{
	assert(0.intToStr == "0");
	assert(1.intToStr == "1");
	assert(10.intToStr == "10");
	assert(123_456_789.intToStr == "123456789");
	assert((-123_456_789).intToStr == "-123456789");
}

package T[] allocate(T)(size_t len){
	version (D_BetterC){
		import core.stdc.stdlib : malloc;
		import core.stdc.string : memset;
		immutable size_t size = T.sizeof * len;
		void* ptr = malloc(size);
		memset(ptr, 0, size);
		return (cast(T*)ptr)[0 .. len];
	} else {
		return new T[len];
	}
}

package T[] duplicate(T)(T[] src){
	version (D_BetterC){
		import core.stdc.stdlib : malloc;
		import core.stdc.string : memcpy;
		immutable size_t size = T.sizeof * src.length;
		void* ptr = malloc(size);
		memcpy(ptr, src.ptr, size);
		return (cast(T*)ptr)[0 .. src.length];
	} else {
		return src.dup;
	}
}
