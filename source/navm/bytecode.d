module navm.bytecode;

import navm.defs;

import utils.lists;
import utils.misc;

import std.conv : to, ConvException;

public import navm.bytecodedefs;
/*
/// Reads a string[] into NaFunction[]
///
/// Throws: Exception if there is some error in input
/// 
/// Returns: the loaded byte code in NaFunction
NaFunction[] readByteCode(string[] input){
	List!NaFunction functions = new List!NaFunction;
	List!(NaData[]) currentFuncArgs = new List!(NaData[]);
	List!Instruction currentFuncInst = new List!Instruction;
	NaFunction current;
	input = input.removeWhitespace;
	const string[][] words = readWords(input);
	uinteger index = 0;
	bool onLoadDeclared = false;
	while (index < words.length){
		string[][] functionWords = (cast(string[][])words).readFunctionWords(index);
		index += functionWords.length;
		// read & replace jump positions with indexes
		replaceJumpPositions(functionWords);
		// check declaration
		if (functionWords[0].length < 2 || functionWords[0][0].lowercase != "def")
			throw new Exception("invalid function declaration");
		if (functionWords[0].length == 2){
			if (!functionWords[0][1].isNum(false))
				throw new Exception("invalid stack length in function declaration");
			current.stackLength = functionWords[0][1].to!uinteger;
			current.type = NaFunction.Type.Function;
		}else if (functionWords[0].length == 3){
			if (!functionWords[0][2].isNum(false))
				throw new Exception("invalid stack length in function declaration");
			if (functionWords[0][1].lowercase !in FUNCTION_TYPE_STRING_MAP)
				throw new Exception("invalid function type");
			current.type = FUNCTION_TYPE_STRING_MAP[functionWords[0][1].lowercase];
			current.stackLength = functionWords[0][2].to!uinteger;
			if (current.type == NaFunction.Type.OnLoad && onLoadDeclared)
				throw new Exception("only 1 onload function allowed");
			onLoadDeclared = onLoadDeclared || current.type == NaFunction.Type.OnLoad;
		}else
			throw new Exception("invalid function declaration");
		// start reading instructions
		foreach (i; 1 .. functionWords.length){
			Instruction inst;
			string lCaseInst = functionWords[i][0].lowercase;
			if (lCaseInst in INSTRUCTION_STRING_MAP)
				inst = INSTRUCTION_STRING_MAP[lCaseInst];
			else
				throw new Exception(functionWords[i][0] ~ " is not a valid instruction");
			NaData[] args;
			args.length = functionWords[i].length - 1;
			foreach (argNo; 0 .. args.length)
				args[argNo] = readData(functionWords[i][argNo + 1]);
			currentFuncInst.append(inst);
			currentFuncArgs.append(args);
		}
		// add it to list
		current.arguments = currentFuncArgs.toArray;
		current.instructions = currentFuncInst.toArray;
		functions.append(current);
		currentFuncArgs.clear;
		currentFuncInst.clear;
	}
	.destroy(currentFuncArgs);
	.destroy(currentFuncInst);
	NaFunction[] r = functions.toArray;
	.destroy(functions);
	return r;
}*/

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

/// Removes whitespace from multiple strings. IF a string is whitespace only, its excluded from output
/// 
/// Returns: string[] with minimal whitespace
string[] removeWhitespace(char[] whitespace=[' ','\t'], char comment='#')(string[] input){
	input = input.dup;
	uinteger writeIndex = 0;
	for (uinteger i = 0; i < input.length; i ++){
		const string line = input[i].removeWhitespace;
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
		r.strVal = strReplaceSpecial(strData[1 .. $-1]).to!dstring;
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