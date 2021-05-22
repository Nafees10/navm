module navm.bytecode;

import utils.ds;
import utils.misc;

import std.conv : to;

/// To store a single line of bytecode. This is used for raw bytecode.
public struct Statement{
	/// label, if any, otherwise, null or empty string
	string label;
	/// instruction name
	string instName;
	/// arguments, if any. These are ignored if `instName.length == 0`
	string[] arguments;
	/// comment, if any
	string comment;
	/// postblit
	this(this){
		this.label = this.label.dup;
		this.instName = this.instName.dup;
		this.arguments = this.arguments.dup;
		this.comment = this.comment.dup;
	}
	/// constructor, for instruction + args + comment
	this(string instName, string[] arguments=[], string comment = ""){
		this.instName = instName;
		this.arguments = arguments.dup;
		this.comment = comment;
	}
	/// constructor, for label + instruction
	this(string label, string instName, string[] arguments=[], string comment = ""){
		this.label = label;
		this.instName = instName;
		this.arguments = arguments.dup;
		this.comment = comment;
	}
	/// Reads statement from string
	void fromString(string statement){
		string[] separated = statement.separateWhitespace();
		if (separated.length == 0)
			return;
		if (separated[0].length && separated[0][$-1] == ':'){
			this.label = separated[0][0 .. $-1];
			separated = separated[1 .. $];
			if (separated.length == 0)
				return;
		}
		this.instName = separated[0];
		if (separated.length > 1)
			this.arguments = separated[1 .. $];
	}
	/// Returns: string representation of this statement
	string toString(){
		string r;
		if (label.length)
			r = label ~ ": ";
		r ~= instName;
		foreach (arg; arguments)
			r ~= ' ' ~ arg;
		if (comment.length)
			r ~= "#"~comment;
		return r;
	}
}
/// 
unittest{
	Statement s;
	s.fromString("someLabel: someInst arg1 arg2#comment");
	assert(s == Statement("someLabel", "someInst", ["arg1", "arg2"]));
}

/// Stores bytecode that is almost ready to be used with NaVM.
public class NaBytecode{
private:
	ushort[] _instCodes; /// codes of instructions
	NaInstArg[] _instArgs; /// instruction arguments
	uinteger[2][] _labelIndexes; /// [codeIndex, argIndex] for each label index
	string[] _labelNames; /// label names
	NaInstTable _instTable; /// the instruction table
public:
	/// constructor
	this(NaInstTable instructionTable){
		this._instTable = instructionTable;
	}
	~this(){}
	/// Returns: instruction codes
	@property ushort[] instCodes(){
		return _instCodes;
	}
	/// Returns: array of instruction pointers. invalid instructions will have null ptr
	@property void delegate()[] instPtrs(){
		void delegate()[] r;
		r.length = _instCodes.length;
		foreach (i; 0 .. r.length){
			try
				r[i] = _instTable.getInstructionPtr(_instCodes[i]);
			catch (Exception e){
				.destroy(e);
				r[i] = null;
			}
		}
		return r;
	}
	/// Returns: arguments for instructions
	@property NaInstArg[] instArgs(){
		return _instArgs;
	}
	/// Returns: label indexes (`[instructionIndex, argIndex]`)
	@property uinteger[2][] labelIndexes(){
		return _labelIndexes;
	}
	/// Returns: label names, corresponding to labelIndexes
	@property string[] labelNames(){
		return _labelNames;
	}
	/// Discards any existing bytecode
	void clear(){
		_instCodes.length = 0;
		_instArgs.length = 0;
		_labelIndexes.length = 0;
		_labelNames.length = 0;
	}
	/// Verifies a loaded bytecode, to make sure only valid instructions exist, and correct number of arguments and types are loaded
	/// 
	/// Returns: true if verified without errors, false if there were errors.
	bool verify(){
		if (_labelNames.length != _labelIndexes.length)
			return false;
		uinteger argInd;
		uinteger[2][] labels = _labelIndexes.dup; // remove elements from this when they are determined valid. if length>0 at end, remaining invalid
		foreach (i; 0 .. _instCodes.length){
			NaInst inst;
			try
				inst = _instTable.getInstruction(_instCodes[i]);
			catch (Exception e){
				.destroy(e);
				return false;
			}
			if (_instArgs.length < argInd || _instArgs.length - argInd < inst.arguments.length)
				return false; // if there arent enough arguments
			NaInstArg[] args = _instArgs[argInd .. argInd + inst.arguments.length];
			foreach (typeInd; 0 .. args.length){
				if ((args[typeInd].type & inst.arguments[typeInd]) != inst.arguments[typeInd])
					return false;
			}
			foreach (labInd; 0 .. labels.length){
				if (labels[labInd][0] == i){
					if (labels[labInd][1] != argInd)
						return false;
					labels[labInd] = labels[$-1];
					labels.length --;
				}
			}
			argInd += inst.arguments.length;
		}
		return labels.length == 0;
	}
	/// Adds a statement at end of existing bytecode
	/// 
	/// Returns: true if no errors, false if not done due to errors
	bool append(Statement statement, ref string error){
		if (statement.label.length){
			if (_labelNames.hasElement(statement.label.lowercase)){
				error = "label `" ~ statement.label ~ "` used multiple times";
				return false;
			}
			_labelIndexes ~= [_instCodes.length, _instArgs.length];
			_labelNames ~= statement.label.lowercase;
		}
		if (statement.instName.length){
			NaInstArg[] args;
			NaInstArgType[] types;
			args.length = statement.arguments.length;
			types.length = args.length;
			foreach (index, arg; statement.arguments){
				try{
					args[index] = readData(arg);
				}catch (Exception e){
					error ~= "argument `"~arg~"`: "~e.msg;
					.destroy(e);
					return false;
				}
			}
			immutable integer code = _instTable.getInstruction(statement.instName.lowercase, types);
			if (code == -1){
				error = "instruction does not exist or invalid arguments";
				return false;
			}
			_instCodes ~= cast(ushort)code;
			_instArgs ~= args;
		}
		return true;
	}
	/// ditto
	bool append(Statement statement){
		string error;
		return this.append(statement, error);
	}
	/// ditto
	bool append(string statementStr, ref string error){
		Statement statement;
		statement.fromString(statementStr);
		return this.append(statement, error);
	}
	/// ditto
	bool append(string statementStr){
		Statement statement;
		statement.fromString(statementStr);
		return this.append(statement);
	}
	/// Loads bytecode from `Statement[]`. Discards any existing bytecode
	/// 
	/// Returns: [] if done without errors. error descriptions if there were errors
	string[] load(Statement[] statements){
		this.clear();
		statements = statements.dup;
		string[] errors;
		foreach (i, statement; statements){
			string error;
			if (!append(statement, error))
				errors ~= "line "~(i+1).to!string~": "~error;
		}
		return errors;
	}
}

/// same as NaBytecode, but also works with binary bytecode (see `spec/binarybytecode.md`)
public class NaBytecodeBinary : NaBytecode{
private:
	/// magic number
	const ubyte[7] MAGIC_NUM = cast(ubyte[7])"NAVMBC-";
	/// version bytes
	const ushort SIG_VER = 0x0001;
	/// number of bytes after magic bytes+version bytes to ignore
	const ubyte MAGIC_BYTES_IGNORE = 8;

	ByteStream _bin;
	ubyte[] _sig;
	ubyte[] _metadata;
public:
	/// constructor
	this(NaInstTable instructionTable, ubyte[] magicNumberPost){
		super(instructionTable);
		this.magicNumberPost = magicNumberPost;
	}
	/// postfix for magic number
	@property ubyte[] magicNumberPost(){
		return _sig.dup;
	}
	/// postfix for magic number
	/// If the newVal is too long, the first bytes are used. If too short, 0x00 is used to fill
	@property ubyte[] magicNumberPost(ubyte[] newVal){
		_sig.length = MAGIC_BYTES_IGNORE;
		_sig[] = 0x00;
		immutable uinteger len = newVal.length > MAGIC_BYTES_IGNORE ? MAGIC_BYTES_IGNORE : newVal.length;
		_sig[0 .. len] = newVal[0 .. len];
		return _sig.dup;
	}
	/// the metadata stored alongside
	@property ubyte[] metadata(){
		return _metadata;
	}
	/// ditto
	@property ubyte[] metadata(ubyte[] newVal){
		return _metadata = newVal;
	}
	/// the ByteStream storing bytecode. Be aware that this will be destroyed when NaBytecodeBinary is destroyed
	@property ByteStream binCode(){
		return _bin;
	}
	/// Prepares binary bytecode
	void writeBinCode(){
		_bin.size = 0;
		_bin.grow = true;
		_bin.maxSize = 0;
		// start by signature
		_bin.writeRaw(MAGIC_NUM);
		_bin.write(cast(ushort)SIG_VER);
		_bin.writeRaw(_sig);
		// metadata
		_bin.writeArray(_metadata, 8);
		// instruction codes
		_bin.writeArray(_instCodes, 8);
		// args
		_bin.write(_instArgs.length, 8); /// number of args
		foreach (i, arg; _instArgs){
			_bin.write(arg.type, 1);
			if (arg.type == NaInstArgType.LiteralBoolean)
				_bin.write(_instArgs[i].boolVal, 1);
			else if (arg.type == NaInstArgType.LiteralString || arg.type == NaInstArgType.Label)
				_bin.writeArray(_instArgs[i].strVal, 8);
			else // everything else is 8 bytes:
				_bin.write(_instArgs[i].intVal,8);
		}
		// labels
		_bin.write(_labelIndexes.length, 8); // number of labels
		foreach (i, label; _labelIndexes){
			_bin.write(label[0], 8); // code index
			_bin.write(label[1], 8); // instruction index
			_bin.writeArray(_labelNames[i], 8); // name
		}
	}
	/// Reads binary bytecode. Any existing bytecode is `clear()`ed
	/// 
	/// Returns: true on success, false if file is malformed
	bool readBinCode(){
		this.clear;
		_metadata = [];
		_sig = [];
		if (_bin.size <= MAGIC_NUM.length + SIG_VER.sizeof + MAGIC_BYTES_IGNORE)
			return false;
		ubyte[] buffer;
		uinteger readCount;
		bool incompleteRead;
		buffer.length = MAGIC_NUM.length;
		_bin.seek=0;
		if (_bin.readRaw(buffer) != buffer.length || buffer != MAGIC_NUM)
			return false;
		if (_bin.read!ushort != SIG_VER)
			return false;
		_sig.length = MAGIC_BYTES_IGNORE;
		_bin.readRaw(_sig);
		// read metadata
		_metadata = _bin.readArray!ubyte(readCount,8);
		if (readCount < _metadata.length)
			return false;
		// instruction codes
		_instCodes = _bin.readArray!ushort(readCount, 8);
		if (readCount < _instCodes.length)
			return false;
		// arguments
		_instArgs.length = _bin.read!uinteger(incompleteRead,8);
		if (incompleteRead)
			return false;
		foreach(i; 0 .. _instArgs.length){
			_instArgs[i].type = _bin.read!NaInstArgType(incompleteRead,1);
			if (incompleteRead)
				return false;
			if (_instArgs[i].type == NaInstArgType.LiteralBoolean)
				_instArgs[i].boolVal = _bin.read!bool(incompleteRead, 1);
			else if (_instArgs[i].type == NaInstArgType.LiteralString || _instArgs[i].type == NaInstArgType.Label){
				_instArgs[i].strVal = cast(string)(_bin.readArray!char(readCount, 8));
				incompleteRead = readCount < _instArgs[i].strVal.length;
			}else // everything else is 8 bytes:
				_instArgs[i].intVal = _bin.read!uinteger(incompleteRead, 8);
			if (incompleteRead)
				return false;
		}
		// labels
		_labelIndexes.length = _bin.read!uinteger(incompleteRead,8);
		if (incompleteRead)
			return false;
		_labelNames.length = _labelIndexes.length;
		foreach (i; 0 .. _labelIndexes.length){
			_labelIndexes[0] = _bin.read!uinteger(incompleteRead, 8);
			if (incompleteRead)
				return false;
			_labelIndexes[1] = _bin.read!uinteger(incompleteRead, 8);
			if (incompleteRead)
				return false;
			_labelNames[i] = cast(string)_bin.readArray!char(readCount, 8);
			if (readCount < _labelNames[i].length)
				return false;
		}
		return true;
	}
}

/// Stores an instruction table
public class NaInstTable{
private:
	NaInst[ushort] _instructions; /// avaliable instructions. index is code
	void delegate()[ushort] _instPtrs; /// pointers for instruction codes
public:
	/// constructor
	this(){

	}
	/// destructor
	~this(){}
	/// Adds a new instruction.  
	/// If `inst.code == 0`, Finds an available code, assigns `inst.code` that code.  
	/// Otherwise `inst.code` is used, if available, or -1 returned.
	/// 
	/// Returns: instruction code if success, or -1 in case of error  
	/// Error can be: code!=0 and code already used. No more codes left. Or another instruction with same name and arg types exists
	integer addInstruction(ref NaInst inst, void delegate() ptr = null){
		if (inst.code == 0){
			// find code
			foreach (ushort i; 0 .. ushort.max){
				if (i ! in _instructions){
					inst.code = i;
					break;
				}
			}
			return -1;
		}else if (inst.code in _instructions)
			return -1;
		// now make sure no other instruction with same name can be called with these args
		if (getInstruction(inst.name, inst.arguments) == -1){
			_instructions[inst.code] = inst;
			_instPtrs[inst.code] = ptr;
			return inst.code;
		}
		return -1;
	}
	/// Finds the instruction with matching code
	/// 
	/// Returns: the instruction.
	/// 
	/// Throws: Exception if doesnt exist
	NaInst getInstruction(ushort code){
		foreach (inst; _instructions){
			if (inst.code == code)
				return inst;
		}
		throw new Exception("instruction with code=" ~ code.to!string ~ " does not exist");
	}
	/// Finds an instruction that can be called with arguments with a matching name
	/// 
	/// Returns: the instruction code for an instruction that can be called, or -1 if doesnt exist
	integer getInstruction(string name, NaInstArgType[] arguments){
		foreach (inst; _instructions){
			if (inst.name == name && inst.arguments.length == arguments.length){
				foreach (i; 0 .. arguments.length){
					if ((inst.arguments[i] & arguments[i]) != inst.arguments[i])
						return -1;
				}
				return inst.code;
			}
		}
		return -1;
	}
	/// gets pointer for an instruction. **This can be null**
	/// 
	/// Returns: instruction pointer
	/// 
	/// Throws: Exception if instruction does not exist
	void delegate() getInstructionPtr(ushort code){
		if (code in _instPtrs)
			return _instPtrs[code];
		throw new Exception("instruction with code=" ~ code.to!string ~ " does not exist");
	}
	/// whether an instruction exists
	/// Returns: true if an instruction exists
	bool instructionExists(ushort code){
		return (code in _instructions) !is null;
	}
	/// ditto
	bool instructionExists(string name){
		foreach (inst; _instructions){
			if (inst.name == name)
				return true;
		}
		return false;
	}
}

private alias NaInstArgType = NaInstArg.Type;

/// Stores an argument for instruction
public struct NaInstArg{
	/// Possible types
	enum Type : ubyte{
		Literal = 			0B00000001, /// any literal
		LiteralInteger = 	0B00000011, /// integer, positive or negative
		LiteralUInteger = 	0B00000111, /// integer, >=0, or could also be a binary or hexadecimal number. This is still stored in `intVal`, but is >=0
		LiteralBoolean =	0B00001001, /// true or false
		LiteralString =		0B00010001, /// a string
		LiteralDouble = 	0B00100001, /// a double (float)
		Label = 			0B01000000, /// a valid label (aka jump position)
		Address = 			0B10000000, /// an address to an element on stack
	}
	Type type; /// type of currently stored argument
	union{
		bool boolVal; /// boolean value
		char charVal; /// char value
		integer intVal; /// integer value
		double doubleVal; /// double/float value
		string strVal; /// string value
	}
	/// constructor
	/// data can be any of the type which it can store
	this (T)(T data, Type type){
		static if (is (T == int) || is (T == long) || is (T == uint) || is (T == ulong)){
			intVal = data;
		}else static if (is (T == double) || is (T == float)){
			doubleVal = data;
		}else static if (is (T == char)){
			charVal = data;
		}else static if (is (T == char[]) || is (T == string)){
			strVal = cast(string)data;
		}else static if (is (T == bool)){
			boolVal = data;
		}else{
			throw new Exception("cannot store "~T.stringof~" in NaInstArg");
		}
		this.type = type;
	}
}

/// stores an data about available instruction
public struct NaInst{
	/// name of instruction, **in lowercase**
	string name;
	/// value when read as a ushort;
	ushort code = 0x0000;
	/// what type of arguments are expected
	NaInstArgType[] arguments;
	/// constructor
	this (string name, uinteger code, NaInstArgType[] arguments = []){
		this.name = name;
		this.code = cast(ushort)code;
		this.arguments = arguments.dup;
	}
	/// constructor
	this (string name, NaInstArgType[] arguments = []){
		this.name = name;
		this.code = 0;
		this.arguments = arguments.dup;
	}
}

/// Reads data from a string (which can be string, char, double, integer, bool)
/// 
/// Addresses are read as integers
/// 
/// Returns: the data in NaInstArg
/// 
/// Throws: Exception if data is invalid
public NaInstArg readData(string strData){
	if (strData.length == 0)
		throw new Exception("cannot read data from empty string");
	if (["true", "false"].hasElement(strData)){
		return NaInstArg(strData == "true", NaInstArg.Type.LiteralBoolean);
	}
	if (strData[0] == '@' && isNum(strData[1 .. $], false))
		return NaInstArg(to!integer(strData[1 .. $]), NaInstArg.Type.Address);
	NaInstArg r;
	if (strData.isNum(false)){
		r.intVal = strData.to!integer;
		if (r.intVal >= 0)
			r.type = NaInstArg.Type.LiteralUInteger;
		else
			r.type = NaInstArg.Type.LiteralInteger;
		return r;
	}
	if (strData.length >= 2 && strData[0] == '0' && (strData[1] == 'x' || strData[1] == 'B')){
		r.type = NaInstArg.Type.LiteralUInteger;
		if (strData.length == 2)
			r.intVal = 0;
		if (strData[1] == 'x')
			r.intVal = readHexadecimal(strData[2 .. $]);
		r.intVal = readBinary(strData[2 .. $]);
		return r;
	}
	if (strData[0] == '\"'){
		r.type = NaInstArgType.LiteralString;
		r.strVal = strReplaceSpecial(strData[1 .. $-1]);
		return r;
	}
	if (strData.isNum(true))
		return NaInstArg(to!double(strData), NaInstArg.Type.LiteralDouble);
	if (strData[0] == '\''){
		r.type = NaInstArgType.Literal;
		strData = strData.dup;
		strData = strReplaceSpecial(strData[1 .. $ -1]);
		if (strData.length > 1)
			throw new Exception("' ' can only contain 1 character");
		if (strData.length < 1)
			throw new Exception("no character provided in ''");
		r.charVal = strData[0];
		return r;
	}
	// well it can only be a label now
	r.type = NaInstArgType.Label;
	r.strVal = strData.lowercase;
	return r;
}
/// 
unittest{
	NaInstArgType type;
	assert("true".readData(type) == NaData(true));
	assert(type == NaInstArgType.LiteralBoolean);
	assert("false".readData(type) == NaData(false));
	assert(type == NaInstArgType.LiteralBoolean);

	assert("@15".readData(type) == NaData(15));
	assert(type == NaInstArgType.Address);
	
	assert("15".readData(type) == NaData(15));
	assert(type == NaInstArgType.LiteralUInteger);
	assert("0".readData(type) == NaData(0));
	assert(type == NaInstArgType.LiteralUInteger);
	assert("-1".readData(type) == NaData(-1));
	assert(type == NaInstArgType.LiteralInteger);
	assert("\"str\\t\"".readData(type).strVal == "str\t".to!dstring);
	assert(type == NaInstArgType.Literal);

	assert("potato".readData(type).strVal == "potato".to!dstring);
	assert(type == NaInstArgType.Label);
}

/// Reads a hexadecimal number from string
/// 
/// Returns: the number in a uinteger
/// 
/// Throws: Exception in case string is not a hexadecimal number, or too big to store in uinteger, or empty string
private uinteger readHexadecimal(string str){
	import std.range : iota, array;
	if (str.length == 0)
		throw new Exception("cannot read hexadecimal number from empty string");
	if (str.length > uinteger.sizeof * 2) // str.length / 2 = numberOfBytes 
		throw new Exception("hexadecimal number is too big to store in uinteger");
	static char[16] DIGITS = iota('0', '9'+1).array ~ iota('a', 'f'+1).array;
	str = str.lowercase;
	if (!(cast(char[])str).matchElements(DIGITS))
		throw new Exception("invalid character in hexadecimal number");
	uinteger r;
	immutable uinteger lastInd = str.length - 1;
	foreach (i, c; str){
		r |= DIGITS.indexOf(c) << 4 * (lastInd-i);
	}
	return r;
}
/// 
unittest{
	assert("FF".readHexadecimal == 0xFF);
	assert("F0".readHexadecimal == 0xF0);
	assert("EF".readHexadecimal == 0xEF);
	assert("A12F".readHexadecimal == 0xA12F);
}

/// Reads a binary number from string
/// 
/// Returns: the number in a uinteger
/// 
/// Throws: Exception in case string is not a binary number, or too big to store in uinteger, or empty string
private uinteger readBinary(string str){
	if (str.length == 0)
		throw new Exception("cannot read binary number from empty string");
	if (str.length > uinteger.sizeof * 8)
		throw new Exception("binary number is too big to store in uinteger");
	if (!(cast(char[])str).matchElements(['0','1']))
		throw new Exception("invalid character in binary number");
	uinteger r;
	immutable uinteger lastInd = str.length-1;
	foreach (i, c; str){
		if (c == '1')
			r |= 1 << (lastInd - i);
	}
	return r;
}
/// 
unittest{
	assert("01010101".readBinary == 0B01010101);
}

/// reads a string into substrings separated by whitespace. Strings are read as a whole
/// 
/// Returns: substrings
/// 
/// Throws: Exception if string not closed
private string[] separateWhitespace(char[] whitespace=[' ','\t'], char comment='#')(string line){
	string[] r;
	for (uinteger i, readFrom; i < line.length; i++){
		immutable char c = line[i];
		if (c == comment){
			if (readFrom < i)
				r ~= line[readFrom .. i].dup;
			break;
		}
		if (c == '"' || c == '\''){
			if (readFrom < i)
				r ~= line[readFrom .. i].dup;
			readFrom = i;
			immutable integer endIndex = line.strEnd(i);
			if (endIndex < 0)
				throw new Exception("string not closed");
			r ~= line[readFrom .. endIndex+1].dup;
			readFrom = endIndex+1;
			i = endIndex;
			continue;
		}
		if (whitespace.hasElement(c)){
			if (readFrom < i)
				r ~= line[readFrom .. i].dup;
			while (i < line.length && whitespace.hasElement(line[i]))
				i ++;
			readFrom = i;
			i --; // back to whitespace, i++ in for(..;..;) exists
			continue;
		}
		if (i+1 == line.length && readFrom < i){
			r ~= line[readFrom .. $].dup;
		}
	}
	return r;
}
///
unittest{
	assert("potato".separateWhitespace == ["potato"]);
	assert("potato potato".separateWhitespace == ["potato", "potato"]);
	assert(" a b \"str\"".separateWhitespace == ["a", "b", "\"str\""]);
	assert("a b 'c' \"str\"".separateWhitespace == ["a", "b", "'c'", "\"str\""]);
	assert("\ta   \t b\"str\"".separateWhitespace == ["a", "b", "\"str\""]);
	assert("   a   b  'c'\"str\"'c'".separateWhitespace == ["a", "b", "'c'", "\"str\"", "'c'"]);
	assert("a 'b'#c".separateWhitespace == ["a", "'b'"]);
	assert("a: a b#c".separateWhitespace == ["a:","a", "b"]);
	assert("a 'b' #c".separateWhitespace == ["a", "'b'"]);
}

/// ditto
private string[][] separateWhitespace(string[] lines){
	string[][] r;
	r.length = lines.length;
	foreach (i; 0 .. lines.length)
		r[i] = separateWhitespace(lines[i]);
	return r;
}

/// Returns: the index where a string ends, -1 if not terminated
private integer strEnd(char specialCharBegin='\\')(string s, uinteger startIndex){
	uinteger i;
	immutable char strTerminator = s[startIndex];
	for (i = startIndex+1; i < s.length; i ++){
		if (s[i] == strTerminator){
			return i;
		}
		if (s[i] == specialCharBegin){
			i ++;
			continue;
		}
	}
	return -1;
}
///
unittest{
	assert("st\"sdfsdfsd\"0".strEnd(2) == 11);
}

/// Returns: string with special characters replaced with their actual characters (i.e, \t replaced with tab, \n with newline...)
private string strReplaceSpecial(char specialCharBegin='\\')
(string s, char[char] map = ['t' : '\t', 'n' : '\n','\\':'\\']){
	char[] r = [];
	for (uinteger i = 0; i < s.length; i ++){
		if (s[i] == specialCharBegin && i + 1 < s.length && s[i+1] in map){
			r ~= map[s[i+1]];
			i++;
			continue;
		}
		r ~= s[i];
	}
	return cast(string)r;
}
///
unittest{
	assert("newline:\\ntab:\\t".strReplaceSpecial == "newline:\ntab:\t");
}