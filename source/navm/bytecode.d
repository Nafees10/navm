module navm.bytecode;

import navm.navm : NaData;

import utils.lists;
import utils.misc;

import std.conv : to;

/// To store a single line of bytecode. This is used for raw bytecode.  
/// Prefer using array of this to write bytecode, then load into NaBytecode to store or use
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

/// Stores bytecode that is almost ready to be used with NaVM.
class NaBytecode{
private:
	ushort[] _instCodes; /// codes of instructions
	NaData[] _instArgs; /// instruction arguments
	NaInstArgType[] _instArgTypes; /// instruction argument types
	uinteger[2][] _labelIndexes; /// [codeIndex, argIndex] for each label index
	string[] _labelNames; /// label names
	NaInstTable _instTable; /// the instruction table
public:
	/// constructor
	this(NaInstTable instructionTable){
		this._instTable = instructionTable;
	}
	~this(){}
	/// Discards any existing bytecode
	void clear(){
		_instCodes.length = 0;
		_instArgs.length = 0;
		_instArgTypes.length = 0;
		_labelIndexes.length = 0;
		_labelNames.length = 0;
	}
	/// Verifies a loaded bytecode, to make sure only valid instructions exist, and correct number of arguments and types are loaded
	/// 
	/// Returns: true if verified without errors, false if there were errors.
	bool verify(){
		if (_instArgs.length != _instArgTypes.length || _labelNames.length != _labelIndexes.length)
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
			if (_instArgTypes.length < argInd || _instArgTypes.length - argInd < inst.arguments.length)
				return false; // if there arent enough arguments
			NaInstArgType[] types = _instArgTypes[argInd .. argInd + inst.arguments.length];
			foreach (typeInd; 0 .. types.length){
				if ((types[typeInd] & inst.arguments[typeInd]) != inst.arguments[typeInd])
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
	/// Loads bytecode from `Statement[]`. Discards any existing bytecode
	/// 
	/// Returns: [] if done without errors. error descriptions if there were errors
	string[] load(Statement[] statements){
		this.clear();
		statements = statements.dup;
		string[] errors;
		foreach (i, statement; statements){
			if (statement.label.length){
				if (_labelNames.hasElement(statement.label.lowercase)){
					errors ~= "line: "~ (i+1).to!string ~ " label `" ~ statement.label ~ "` used multiple times";
					continue;
				}
				_labelIndexes ~= [_instCodes.length, _instArgs.length];
				_labelNames ~= statement.label.lowercase;
			}
			if (statement.instName.length){
				NaData[] args;
				NaInstArgType[] types;
				args.length = statement.arguments.length;
				types.length = args.length;
				foreach (index, arg; statement.arguments){
					try{
						args[index] = readData(arg, types[index]);
					}catch (Exception e){
						errors ~= "line: "~(i+1).to!string~" argument `"~arg~"`: "~e.msg;
						.destroy(e);
					}
				}
				immutable integer code = _instTable.getInstruction(statement.instName.lowercase, types);
				if (code == -1)
					errors ~= "line: "~(i+1).to!string ~ ": instruction does not exist or invalid arguments";
				_instCodes ~= cast(ushort)code;
				_instArgs ~= args;
				_instArgTypes ~= types;
			}
		}
		return [];
	}
}

/// Stores an instruction table
class NaInstTable{
private:
	NaInst[] _instructions; /// avaliable instructions. Index and code arent related
	bool[uinteger] _codeIsUsed; /// if an instruction code is used
	/// Returns: true if a code is used, false if not
	bool codeUsed(uinteger code){
		if (code in _codeIsUsed)
			return _codeIsUsed[code];
		return false;
	}
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
	integer addInstruction(ref NaInst inst){
		if (inst.code == 0){
			// find code
			foreach (ushort i; 0 .. ushort.max){
				if (!codeUsed(i)){
					inst.code = i;
					break;
				}
			}
			return -1;
		}else if (codeUsed(inst.code))
			return -1;
		// now make sure no other instruction with same name can be called with these args
		if (getInstruction(inst.name, inst.arguments) == -1){
			_instructions ~= inst;
			_codeIsUsed[inst.code] = true;
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
	/// whether an instruction exists
	/// Returns: true if an instruction exists
	bool instructionExists(ushort code){
		return codeUsed(code);
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

/// Possible types of arguments for instructions
public enum NaInstArgType : ubyte{
	Literal = 			0B00000001, /// any literal
	LiteralInteger = 	0B00000011, /// integer, positive or negative
	LiteralUInteger = 	0B00000111, /// integer, >=0, or could also be a binary or hexadecimal number
	LiteralBoolean =	0B00001001, /// true or false
	LiteralString =		0B00010001, /// a string (dstring)
	Label = 			0B01000000, /// a valid label (aka jump position)
	Address = 			0B10000000, /// an address to an element on stack
}

/// stores an data about available instruction
public struct NaInst{
	/// name of instruction, **in lowercase**
	string name;
	/// value when read as a ushort;
	ushort code = 0x0000;
	/// what type of arguments are expected
	NaInstArgType[] arguments;
	/// number of elements it will push to stack
	ubyte pushCount = 0;
	/// number of elements it will pop (if `_popCount>=128`, then `popCount = arguments[_popCount-128]`)
	private ubyte _popCount = 0;
	/// Returns: number of elements it will pop
	ubyte popCount(NaData[] args){
		if (_popCount < 128)
			return _popCount;
		return cast(ubyte)(args[_popCount - 128].intVal);
	}
	/// constructor
	this (string name, uinteger code, ubyte popCount = 0, ubyte pushCount = 0, NaInstArgType[] arguments = []){
		this.name = name;
		this.code = cast(ushort)code;
		this._popCount = popCount;
		this.pushCount = pushCount;
		this.arguments = arguments.dup;
	}
	/// constructor, with no push/pop
	this (string name, uinteger code, NaInstArgType[] arguments){
		this.name = name;
		this.code = cast(ushort)code;
		this.arguments = arguments.dup;
	}
}

/// Reads data from a string (which can be string, char, double, integer, bool)
/// 
/// Addresses are read as integers
/// 
/// Returns: the data in NaData
/// 
/// Throws: Exception if data is invalid
public NaData readData(string strData, ref NaInstArgType type){
	if (strData.length == 0)
		throw new Exception("cannot read data from empty string");
	if (["true", "false"].hasElement(strData)){
		type = NaInstArgType.LiteralBoolean;
		return NaData(strData == "true");
	}
	if (strData[0] == '@' && isNum(strData[1 .. $], false)){
		type = NaInstArgType.Address;
		return NaData(to!integer(strData[1 .. $]));
	}
	if (strData.isNum(false)){
		NaData r = NaData(to!integer(strData));
		if (r.intVal >= 0)
			type = NaInstArgType.LiteralUInteger;
		else
			type = NaInstArgType.LiteralInteger;
		return r;
	}
	if (strData.length >= 2){
		if (strData[0] == '0' && (strData[1] == 'x' || strData[1] == 'B')){
			type = NaInstArgType.LiteralUInteger;
			if (strData.length == 2)
				return NaData(0);
			if (strData[1] == 'x')
				return NaData(readHexadecimal(strData[2 .. $]));
			return NaData(readBinary(strData[2 .. $]));
		}
	}
	type = NaInstArgType.Literal;
	if (strData.isNum(true))
		return NaData(to!double(strData));
	if (strData[0] == '\"'){
		// assume the whole thing is string, no need to find string end index
		NaData r;
		r.strVal = cast(dchar[])strReplaceSpecial(strData[1 .. $-1]).to!dstring;
		return r;
	}
	if (strData[0] == '\''){
		NaData r;
		strData = strData.dup;
		strData = strReplaceSpecial(strData[1 .. $ -1]);
		if (strData.length > 1)
			throw new Exception("'' can only contain 1 character");
		if (strData.length < 1)
			throw new Exception("no character provided in ''");
		r.dcharVal = strData[0];
		return r;
	}
	// well it can only be a label now
	type = NaInstArgType.Label;
	NaData r;
	r.strVal = cast(dchar[])(strData.to!dstring);
	return r;
}
/// ditto
public NaData readData(string strData){
	NaInstArgType type;
	return readData(strData, type);
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