module navm.bytecode;

import navm.defs;

import utils.lists;
import utils.misc;

import std.conv : to, ConvException;

public import navm.bytecodedefs : NaFunction;
public import navm.bytecodedefs : Instruction;
public import navm.bytecodedefs : INSTRUCTION_ARG_COUNT;
public import navm.bytecodedefs : INSTRUCTION_PUSH_COUNT;
public import navm.bytecodedefs : instructionPopCount;

/// stores names of byte code instructions in lowercase, mapped to Instruction enum, in assoc_array
private static Instruction[string] INSTRUCTION_STRING_MAP;

static this(){
	import std.traits : EnumMembers;
	Instruction[string] r;
	foreach(inst; EnumMembers!Instruction){
		r[to!string(inst).lowercase] = inst;
	}
	INSTRUCTION_STRING_MAP = r;
}

/// Reads a string[] into NaFunction[]
///
/// Throws: Exception if there is some error in input
/// 
/// Returns: the loaded byte code in NaFunction
NaFunction[] readByteCode(string[] input){
	// remove excess whitespace and comments
	input = input.removeWhitespace;
	// now read it into words
	const string[][] words = readWords(input);
	List!NaFunction functions = new List!NaFunction;
	List!(NaData[]) currentFuncArgs = new List!(NaData[]);
	List!Instruction currentFuncInst = new List!Instruction;
	NaFunction current;
	bool functionDefined = false; // true if its clear that its reading instructions for a function, and stackLength has been defined

	foreach(i, line; words){
		if (functionDefined && line[0].lowercase != "def"){
			Instruction inst;
			string lCaseInst = line[0].lowercase;
			if (lCaseInst.lowercase in INSTRUCTION_STRING_MAP){
				inst = INSTRUCTION_STRING_MAP[lCaseInst];
			}else{
				throw new Exception(lCaseInst~" is not a valid instruction");
			}
			NaData[] arguments;
			arguments.length = line.length - 1;
			for (uinteger argNo = 0; argNo < arguments.length; argNo++){
				arguments[argNo] = readData(line[1 + argNo]);
			}
			currentFuncInst.append(inst);
			currentFuncArgs.append(arguments);
		}else{
			if (line[0] == "def" && line.length == 2){
				if (functionDefined){
					// write last one to list
					current.arguments = currentFuncArgs.toArray;
					current.instructions = currentFuncInst.toArray;
					functions.append(current);
					currentFuncArgs.clear;
					currentFuncInst.clear;
					current = NaFunction();
				}
				functionDefined = true;
				if (line[1].isNum(false))
					current.stackLength = to!uinteger(line[1]);
				else
					throw new Exception("stack length must be an integer");
			}else
				throw new Exception("function definition expected");
		}
	}
	if (functionDefined){
		// write last one to list
		current.arguments = currentFuncArgs.toArray;
		current.instructions = currentFuncInst.toArray;
		functions.append(current);
	}
	.destroy(currentFuncArgs);
	.destroy(currentFuncInst);
	NaFunction[] r = functions.toArray;
	.destroy(functions);
	return r;
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
	if (r.length > 0 && whitespace.hasElement(r[r.length-1])){
		r = r[0 .. r.length-1];
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

/// Removes whitespace from multiple strings. IF a string is whitespace only, its excluded from output
/// 
/// Returns: string[] with minimal whitespace
string[] removeWhitespace(char[] whitespace=[' ','\t'], char comment='#')(string[] input){
	input = input.dup;
	uinteger writeIndex = 0;
	for (uinteger i = 0; i < input.length; i ++){
		string line = input[i].removeWhitespace;
		if (line.length > 0){
			input[writeIndex] = line;
			writeIndex ++;
		}
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
		string[] currentWords = words.toArray;
		if (currentWords.length)
			lines.append(currentWords);
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

/// Reads byte code for a single function from the whole bytecode
/// 
/// Returns: the bytecode for single function
private string[][] readFunctionWords(string[][] bytecode, uinteger defIndex){
	// read till it finds another def, or the bytecode ends
	uinteger i, end = defIndex+1;
	for (i = defIndex+1; i < bytecode.length; i ++){
		if (bytecode[i].length > 0 && bytecode[i][0] == "def"){
			end = i;
			break;
		}
	}
	if (i == bytecode.length)
		end = bytecode.length;
	return bytecode[defIndex .. end].dup;
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
	// now checking for arrays
	if (strData[0] == '['){
		NaData r = NaData(cast(NaData[])[]);
		string[] elements = [];
		for (uinteger i = 1, bracketEnd = bracketPos(cast(char[])strData, 0); i < bracketEnd; i ++){
			if (strData[i] == ' ')
				continue;
			if (strData[i] != ']'){
				elements ~= readElement(strData, i);
				i += elements[elements.length-1].length;
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
		r.strVal = cast(char[])(strReplaceSpecial(strData[1 .. strData.length-1]));
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
		r.charVal = strData[0];
		return r;
	}
	return NaData();
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
private string strReplaceSpecial(char specialCharBegin='\\', char[char] map = ['t' : '\t', 'n' : '\n','\\':'\\'])(string s){
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