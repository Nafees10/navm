module navm.error;

/// NaVM Error
public struct Err{
	/// Possible error types
	public enum Type{
		BinaryOnBigEndian, /// attempting to use binary on big endian CPU
		StreamSizeInvalid, /// binary stream size is invalid
		StreamHeaderInvalid, /// binary stream header is invalid
		StreamVersionInvalid, /// binary stream version is invalid
		LabelUndefined, /// label not defined but used
		LabelRedeclare, /// label declared multiple times
		InstructionArgCountInvalid, /// invalid number of arguments
		InstructionExpected, /// instruction was expected
		InstructionArgInvalid, /// invalid argument passed to instruction
		ValueNotInt, /// value is not integer
		ValueNotFloat, /// value is not float
		ValueNotBool, /// value is not boolean
		ValueNotString, /// value is not string
		ValueNotChar, /// value is not char
		ValueNotHex, /// value is not hexadecimal int
		ValueNotBin, /// value is not binary int
		StringNotClosed, /// string not closed
	}

	public Type type; /// Type of this error
	public string message; /// Message
	@disable this();
	this (Type type, string message = null) pure {
		this.type = type;
		this.message = message;
	}
}

/// Error or a Value of type T
public struct ErrVal(T){
	private bool _isErr;
	private union{
		T _val;
		Err _err;
	}

	/// Returns: true if this is erroneous
	public @property bool isErr() const pure {
		return _isErr;
	}
	/// Returns: error
	public @property Err err() pure {
		assert (isErr);
		return _err;
	}
	/// Returns: value
	public @property T val() pure {
		assert (!isErr);
		return _val;
	}

	alias val this;

	/// constructor
	this(Err err) pure {
		this._isErr = true;
		this._err = err;
	}
	/// ditto
	this(T val) pure {
		this._isErr = false;
		this._val = val;
	}
}
