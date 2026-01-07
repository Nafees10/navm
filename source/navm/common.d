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

pragma(inline, true){
	/// Reads a void[] as a type
	/// Returns: value in type T
	package inout(T) as(T)(inout void[] data) pure {
		assert(data.length >= T.sizeof);
		return *(cast(T*)data.ptr);
	}

	/// Returns: void[] against a value of type T
	package void[] asBytes(T)(T val) pure {
		void[] ret;
		ret.length = T.sizeof;
		return ret[] = (cast(void*)&val)[0 .. T.sizeof];
	}
}
