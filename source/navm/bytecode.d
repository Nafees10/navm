module navm.bytecode;

import navm.defs;

import utils.lists;
import utils.misc;

import std.conv : to;

/// Class used for storing/constructing bytecode
public class NaBytecode{
private:
	/// where the bytecode is actually stored
	string[] _instructions;
	string[] _arguments;
	/// stores number of elements sitting on stack right now after the last added instruction would be executed
	uinteger _stackLength;
	/// stores max number of elements sitting on stack at any time
	uinteger _stackLengthMax;
	/// stores any elements that have been "bookmarked". Useful for keeping track of elements during constructing byte code
	uinteger[uinteger] _bookmarks;
	/// stores the instruction table
	NaInstruction[] _instructionTable;
public:
	/// constructor
	this(NaInstruction[] instructionTable){
		_instructionTable = instructionTable.dup;
	}
	~this(){
		// nothing to do
	}
	/// Returns: true if a NaInstruction exists in instruction table
	bool hasInstruction(string name, ref NaInstruction instruction){
		foreach (inst; _instructionTable){
			if (name.lowercase == inst.name){
				instruction = inst;
				return true;
			}
		}
		return false;
	}
	/// ditto
	bool hasInstruction(string name){
		NaInstruction dummy;
		return hasInstruction(name, dummy);
	}
	/// adds an instruction to the instruction table
	/// 
	/// Returns: true if it was added, false if not due to name or code already used
	bool addInstructionToTable(NaInstruction instruction){
		foreach (inst; _instructionTable){
			if (inst.name == instruction.name || inst.code == instruction.code)
				return false;
		}
		_instructionTable ~= instruction;
		return true;
	}
	/// goes over bytecode, checks if there are any errors, and converts jump positions to indexes
	/// i.e: makes the byte code a bit more ready for execution
	/// 
	/// Returns: errors in a string[], or an empty array in case no errors
	string[] resolve(){
		string[] errors;
		uinteger[string] jumpPos;
		uinteger instCount = 0;
		for (uinteger i=0, instIndex=0; i < _instructions.length; i ++){
			string name = _instructions[i];
			if (name.length && name[$-1] == ':'){
				name = name[0 .. $-1];
				if (name.lowercase in jumpPos){
					errors ~= "line#"~(i+1).to!string~' '~name~" as jump postion declared multiple times";
					continue;
				}
				if (name.isNum(true)){
					errors ~= "line#"~(i+1).to!string~' '~name~" is an invalid jump position, cannot be digits only.";
					continue;
				}
				jumpPos[name.lowercase] = instIndex;
				continue;
			}
			instIndex ++;
			instCount = instIndex;
		}
		for (uinteger i=0, writeIndex=0; i < _instructions.length; i ++){
			string name = _instructions[i];
			if (name.length && name[$-1] == ':')
				continue;
			if (writeIndex != i){
				_instructions[writeIndex] = name;
				_arguments[writeIndex] = _arguments[i];
			}
			NaInstruction instInfo;
			if (this.hasInstruction(name, instInfo)){
				if (instInfo.needsArg && !_arguments[i].length)
					errors ~= "line#"~(i+1).to!string~' '~name~"  needs argument";
				if (instInfo.argIsJumpPos){
					string arg = _arguments[i].lowercase;
					if (arg.isNum(false)){ // skip it if its an integer already
						_arguments[writeIndex] = arg;
					}else if (jumpPos.keys.hasElement(arg))
						_arguments[writeIndex] = jumpPos[arg].to!string;
					else
						errors ~= "line#"~(i+1).to!string~' '~arg~" is not a valid jump position";
				}
			}else
				errors ~= "line#"~(i+1).to!string~" instruction does not exist";
			writeIndex ++;
		}
		_instructions.length = instCount;
		_arguments.length = instCount;
		return errors;
	}
	/// Returns: the bytecode in a readable format
	string[] getBytecodePretty(){
		string[] r;
		r.length = _instructions.length;
		foreach (i, inst; _instructions){
			r[i] = _instructions[i];
			if (_arguments[i].length)
				r[i] ~= "\t\t" ~ _arguments[i];
		}
		return r;
	}
	/// Call `resolve` before this or prepare for crashes
	/// 
	/// Returns: pointers for all instructions
	void delegate()[] getBytecodePointers(){
		void delegate()[] r;
		r.length = _instructions.length;
		foreach (i, inst; _instructions){
			NaInstruction instInfo;
			hasInstruction(inst, instInfo);
			r[i] = instInfo.pointer;
		}
		return r;
	}
	/// Call `resolve` before this or prepare for crashes
	/// 
	/// Returns: codes for all instructions
	ushort[] getBytecodeCodes(){
		ushort[] r;
		r.length = _instructions.length;
		foreach (i, inst; _instructions){
			NaInstruction instInfo;
			hasInstruction(inst, instInfo);
			r[i] = instInfo.code;
		}
		return r;
	}
	/// Call `resolve` before this.
	/// 
	/// Returns: arguments for each instruction NaData[]
	/// 
	/// Throws: Exception in case of error in argument
	NaData[] getArgumentsNaData(){
		NaData[] r;
		r.length = _arguments.length;
		foreach (i, arg; _arguments){
			try{
				r[i] = readData(arg);
			}catch (Exception e){
				e.msg = "Line#"~(i+1).to!string~' '~e.msg;
				throw e;
			}
		}
		return r;
	}
	/// Reads from a string[] (follows spec/syntax.md)
	/// 
	/// Returns: errors in a string[], or [] if no errors
	string[] readByteCode(string[] input){
		string[] errors;
		immutable string[][] words = cast(immutable string[][])input.removeWhitespace.readWords();
		foreach (i, lineWords; words){
			if (!lineWords.length)
				continue;
			if (lineWords[0].length){
				if (lineWords[0][$-1] == ':'){
					this.addJumpPos(lineWords[0][0..$-1]);
					continue;
				}
				string error = "";
				if (!this.addInstruction(lineWords[0],
					lineWords.length>1 && lineWords[1].length ? lineWords[1] : "", error))
					errors ~= "line#"~(i+1).to!string~':'~error;
			}
		}
		return errors;
	}
	// functions for generating byte code
	
	/// appends an instruction
	/// 
	/// Returns: true if successful, false if not (writes error in `error`)
	bool addInstruction(string instName, string argument, ref string error){
		import navm.bytecode : removeWhitespace;
		NaInstruction inst;
		if (hasInstruction(instName, inst)){
			if (inst.needsArg && !removeWhitespace(argument).length){
				error = "instruction needs an argument";
				return false;
			}
			NaData arg;
			if (inst.needsArg && !inst.argIsJumpPos){
				try{
					arg = readData(argument);
				}catch (Exception e){
					error = "invalid argument: "~e.msg;
					return false;
				}
				if (_stackLength < inst.popCount(arg)){
					error = "stack does not have enough elements for instruction";
					return false;
				}
			}
			_instructions ~= instName;
			_arguments ~= argument;
			_stackLength -= inst.popCount(arg);
			_stackLength += inst.pushCount;
			_stackLengthMax = _stackLength > _stackLengthMax ? _stackLength : _stackLengthMax;
			return true;
		}
		error = "instruction "~instName~" does not exist";
		return false;
	}
	/// ditto
	bool addInstruction(string instName, string argument){
		string dummy;
		return addInstruction(instName, argument, dummy);
	}
	/// ditto
	bool addInstruction(string instName){
		string dummy;
		return addInstruction(instName, "", dummy);
	}
	/// adds a jump position
	void addJumpPos(string name){
		_instructions ~= name~':';
		_arguments ~= "";
	}
	/// Returns: the number of elements on stack after executing the last added instruction
	@property uinteger elementCount(){
		return _stackLength;
	}
	/// adds a "bookmark" to the last element on stack, so later on, relative to current peek index, bookmark index
	/// can be read.
	/// 
	/// Returns: bookmark id, or -1 if stack empty
	integer addBookmark(){
		if (_stackLength == 0)
			return -1;
		integer bookmarkId;
		for (bookmarkId = 0; bookmarkId <= integer.max; bookmarkId ++)
			if (bookmarkId !in _bookmarks)
				break;
		_bookmarks[bookmarkId] = _stackLength-1;
		return bookmarkId;
	}
	/// removes a bookmark
	/// 
	/// Returns: true if successful, false if does not exists
	bool removeBookmark(uinteger id){
		if (id !in _bookmarks)
			return false;
		_bookmarks.remove(id);
		return true;
	}
	/// gets relative index from current stack index to a bookmark
	/// 
	/// Returns: relative index, or integer.max if bookmark does not exist
	integer bookmarkRelIndex(uinteger id){
		if (id !in _bookmarks)
			return integer.max;
		return _stackLength.to!integer - (_bookmarks[id]+1).to!integer;
	}
}

/// stores an data about available instruction
public struct NaInstruction{
	bool argIsJumpPos = false; /// if the argument to this instruction is a jump position
	string name; /// name of instruction, in lowercase
	ushort code = 0x0000; /// value when read as a ubyte
	bool needsArg; /// if this instruction needs an argument
	ubyte pushCount = 0; /// number of elements it will push to stack
	private ubyte _popCount = 0; /// number of elements it will pop (if ==255, then the argument is the number of elements to pop)
	void delegate() pointer; /// pointer to the delegate behind this instruction
	/// Returns: number of elements it will pop
	ubyte popCount(NaData arg){
		if (_popCount < 255)
			return _popCount;
		return cast(ubyte)(arg.intVal);
	}
	/// constructor, for instruction with no arg, no push/pop
	this (string name, integer code, void delegate() pointer){
		this.name = name.lowercase;
		this.code = cast(ushort)code;
		this.pointer = pointer;
		this.needsArg = false;
		this.pushCount = 0;
		this._popCount = 0;
	}
	/// constructor, for instruction with no arg, but pop and push
	this(string name, integer code, integer popCount, integer pushCount, void delegate() pointer){
		this.name = name.lowercase;
		this.code = cast(ushort)code;
		this.needsArg = false;
		this.pushCount = cast(ubyte)pushCount;
		this._popCount = cast(ubyte)popCount;
		this.pointer = pointer;
	}
	/// full constructor but arg is not jump position
	this (string name, integer code, bool needsArg, integer popCount, integer pushCount, void delegate() pointer){
		this.name = name.lowercase;
		this.code = cast(ushort)code;
		this.needsArg = needsArg;
		this.argIsJumpPos = false;
		this.pushCount = cast(ubyte)pushCount;
		this._popCount = cast(ubyte)popCount;
		this.pointer = pointer;
	}
	/// full constructor
	this (string name, integer code, bool needsArg, bool argIsJumpPos, integer popCount, integer pushCount, void delegate() pointer){
		this.name = name.lowercase;
		this.code = cast(ushort)code;
		this.needsArg = needsArg;
		this.argIsJumpPos = argIsJumpPos;
		this.pushCount = cast(ubyte)pushCount;
		this._popCount = cast(ubyte)popCount;
		this.pointer = pointer;
	}
}

/// Reads data from a string (which can be string, double, integer, or array of any of those types, or array of array...)
/// 
/// Does not care if elements in array are of same type or not.
/// 
/// Returns: the data in NaData
/// 
/// Throws: Exception if data is invalid
public NaData readData(string strData){
	static string readElement(string array, uinteger startIndex){
		if (array[startIndex] == '[')
			return array[startIndex .. bracketPos(cast(char[])array, startIndex)+1];
		// search for ] or ,
		uinteger i = startIndex;
		while (i < array.length && ! [',',']'].hasElement(array[i]))
			i ++;
		return array[startIndex .. i];
	}
	if (strData.length == 0)
		return NaData();
	if (strData.isNum(false))
		return NaData(to!integer(strData));
	if (strData.isNum(true))
		return NaData(to!double(strData));
	if (["true", "false"].hasElement(strData))
		return NaData(strData == "true");
	// now checking for arrays
	if (strData[0] == '['){
		NaData r = NaData(cast(NaData[])[]);
		string[] elements = [];
		for (uinteger i = 1, bracketEnd = bracketPos(cast(char[])strData, 0); i < bracketEnd; i ++){
			if (strData[i] == ' ')
				continue;
			if (strData[i] != ']'){
				elements ~= readElement(strData, i);
				i += elements[$-1].length;
				// skip till ','
				while (![',',']'].hasElement(strData[i]))
					i ++;
			}
		}
		// now convert each of those elements to NaData
		r.arrayVal = new NaData[elements.length];
		foreach (i, element; elements)
			r.arrayVal[i] = readData(element);
		return r;
	}
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
	throw new Exception("invalid data");
}

/// Removes whitespace from a string. And the remaining whitespace is only of one type. e.g: whitespace is ' ' & '\t', 
/// it will replace '\t' with ' ' so less conditions are needed after this
/// 
/// Returns: the string with minimal whitespace (just enough to separate identifiers)
private string removeWhitespace(char[] whitespace=[' ','\t'], char comment='#')(string line){
	char[] r = [];
	bool lastWasWhite = true;
	for (uinteger i = 0; i < line.length; i ++){
		if (line[i] == comment){
			break;
		}
		if (line[i] == '\"'){
			integer endIndex = line.strEnd(i);
			if (endIndex == -1)
				throw new Exception("string not terminated");
			r ~= line[i .. endIndex + 1];
			i = endIndex;
			lastWasWhite = false;
			continue;
		}
		if (whitespace.hasElement(line[i])){
			if (!lastWasWhite){
				r ~= whitespace[0];
			}
			lastWasWhite = true;
		}else{
			lastWasWhite = false;
			r ~= line[i];
		}
	}
	if (r.length > 0 && whitespace.hasElement(r[$-1])){
		r = r[0 .. $-1];
	}
	return cast(string)r;
}
/// 
unittest{
	assert("potato    potato".removeWhitespace == "potato potato");
	assert("potato    \t\t".removeWhitespace == "potato");
	assert("potato  \t  \t  potato  \t#comment".removeWhitespace == "potato potato");
	assert ("   ".removeWhitespace == "");
	assert ("   \t \t".removeWhitespace == "");
	assert ("  # \t \t".removeWhitespace == "");
	assert ("#  # \t \t".removeWhitespace == "");
}

/// Removes whitespace from multiple strings.
/// 
/// Returns: string[] with minimal whitespace
string[] removeWhitespace(char[] whitespace=[' ','\t'], char comment='#')(string[] input){
	input = input.dup;
	uinteger writeIndex = 0;
	for (uinteger i = 0; i < input.length; i ++){
		const string line = input[i].removeWhitespace;
		input[writeIndex] = line;
		writeIndex ++;
	}
	input.length = writeIndex;
	return input;
}

/// reads each line into words (separated by tab and space)
/// 
/// Returns: the words read (stuff inside square brackets is considerd a sinle word)
/// 
/// Throws: Exception if incorrect syntax (in brackets usually)
private string[][] readWords(string[] input){
	List!(string[]) lines = new List!(string[]);
	List!string words = new List!string;
	foreach (line; input){
		for (uinteger i = 0, readFrom = 0; i < line.length; i++){
			if (line[i] == '['){
				if (readFrom < i){
					words.append(line[readFrom .. i]);
					readFrom = i;
				}
				i = bracketPos(cast(char[])line, i);
				words.append(line[readFrom .. i + 1]);
				i ++; // skip the bracket end, the increment done by for will skip the space too
				readFrom = i+1;
				continue;
			}
			if (line[i] == '\"' || line[i] == '\''){
				if (readFrom < i){
					words.append(line[readFrom .. i]);
					readFrom = i;
				}
				immutable integer endIndex = line[i] == '\"' ? strEnd(line,i) : strEnd!('\\','\'')(line, i);
				if (endIndex == -1)
					throw new Exception("string not terminated");
				i = endIndex;
				words.append(line[readFrom .. i+1]);
				readFrom = i + 1;
				continue;
			}
			if (line[i] == ' ' || line[i] == '\t'){
				if (readFrom <= i && removeWhitespace(line[readFrom .. i]).length > 0)
					words.append(line[readFrom .. i]);
				readFrom = i + 1;
			}else if (i +1 == line.length && readFrom <= i){
				words.append(line[readFrom .. i + 1]);
			}
		}
		lines.append(words.toArray);
		words.clear;
	}
	.destroy(words);
	string[][] r = lines.toArray;
	.destroy(lines);
	return r;
}
///
unittest{
	assert(["potato potato",
		"potato [asdf, sdfsdf, [0, 1, 2], 2] asd",
		"   \t",
		"potato \"some String\" \'c\'"].readWords == [
			["potato", "potato"],
			["potato", "[asdf, sdfsdf, [0, 1, 2], 2]", "asd"],
			["potato","\"some String\"","\'c\'"]
		]);
}

/// Returns: the index where a string ends, -1 if not terminated
private integer strEnd(char specialCharBegin='\\', char strTerminator='"')(string s, uinteger startIndex){
	uinteger i;
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
private string strReplaceSpecial(char specialCharBegin='\\', char[char] map = ['t' : '\t', 'n' : '\n','\\':'\\'])
(string s){
	char[] r = [];
	for (uinteger i = 0; i < s.length; i ++){
		if (s[i] == specialCharBegin && i + 1 < s.length && s[i+1] in map){
			r ~= map[s[i+1]];
			i++;
			continue;
		}
		r ~= s[i];
	}
	return r;
}
///
unittest{
	assert("newline:\\ntab:\\t".strReplaceSpecial == "newline:\ntab:\t");
}