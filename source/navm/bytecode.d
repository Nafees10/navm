module navm.bytecode;

import navm.defs;

import utils.lists;
import utils.misc;

import std.conv : to;

/// To store a single line of bytecode
public struct Statement{
	/// label, if any, otherwise, null or empty string
	string label;
	/// instruction name
	string instName;
	/// arguments, if any
	string[] instArguments;
	/// comment, if any
	string comment;
	/// constructor, for instruction + args + comment
	this(string instName, string[] instArguments=[], string comment = ""){
		this.instName = instName;
		this.instArguments = instArguments.dup;
		this.comment = comment;
	}
	/// constructor, for label + instruction
	this(string label, string instName, string[] instArguments=[], string comment = ""){
		this.label = label;
		this.instName = instName;
		this.instArguments = instArguments.dup;
		this.comment = comment;
	}

}

/// Stores bytecode that is almost ready to be used with NaVM
class NaBytecode{
private:
	ushort[] _instCodes; /// codes of instructions
	NaData[] _instArgs; /// instruction arguments
	uinteger[2][] _labelIndexes; /// [codeIndex, argIndex] for each label index
	string[] _labelNames; /// label names
}

/// Possible types of arguments for instructions
public enum NaInstArgType : ubyte{
	Literal = 			0B00000001, /// any literal
	LiteralInteger = 	0B00000011, /// integer, positive or negative
	LiteralUInteger = 	0B00000111, /// integer, >=0, or could also be a binary or hexadecimal number
	LiteralBoolean =	0B00001001, /// true or false
	Label = 			0B00010000, /// a valid label (aka jump position)
	Address = 			0B00100000, /// an address to an element on stack
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

/// Reads a hexadecimal number from string
/// 
/// Returns: the number in a uinteger
/// 
/// Throws: Exception in case string is not a hexadecimal number
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
/// Throws: Exception in case string is not a binary number
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