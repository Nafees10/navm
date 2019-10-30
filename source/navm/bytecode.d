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
	// separate input by words, ignore comments
	const string[][] words = readWords(input);
	List!NaFunction functions = new List!NaFunction;
	List!(NaData[]) currentFuncArgs = new List!(NaData[]);
	List!Instruction currentFuncInst = new List!Instruction;
	NaFunction current;
	bool functionDefined = false; // true if its clear that its reading instructions for a function, and stackLength has been defined

	foreach(i, line; words){
		if (functionDefined){
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
				if (line[1+argNo].isNum(false)){
					arguments[argNo].intVal = to!integer(line[1+argNo]);
				}else
					throw new Exception("instruction arguments can only be integers");
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


/// ignores whitespace (space + tab + comments), then reads each line into words (separated by tab and space)
/// 
/// Returns: the words read
private string[][] readWords(string[] input){
	List!(string[]) outputList = new List!(string[]); /// using this instead of directly array because it'll allocate extra (bit faster)
	List!string lineWords = new List!string;
	foreach(line; input){
		for (uinteger i = 0, readFrom = 0; i < line.length; i ++){
			if (readFrom == i){
				if ([' ', '\t'].hasElement(line[i]))
					readFrom++;
				else if (line[i] == '#')
					break;
			}
			if (readFrom <= i){
				if ([' ', '\t', '#'].hasElement(line[i])){
					lineWords.append(line[readFrom .. i]);
					readFrom = i +1;
					if (line[i] == '#')
						break;
				}else if (i + 1 == line.length){
					lineWords.append(line[readFrom .. i+1]);
					continue;
				}
			}
		}
		if (lineWords.length > 0){
			outputList.append(lineWords.toArray);
			lineWords.clear;
		}
	}
	.destroy(lineWords);
	string[][] r = outputList.toArray;
	.destroy(outputList);
	return r;
}
///
unittest{
	assert(readWords(["abc def #comment", "#comment", "ab#comment", "cd d", " #a"]) == [["abc", "def"],["ab"],["cd","d"]]);
}