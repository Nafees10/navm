module navm.navm;

import navm.defs;
import navm.bytecode;

import std.conv : to;

import utils.lists;
import utils.misc;

public alias NaData = navm.defs.NaData;
public alias NaInstruction = navm.bytecode.NaInst;
public alias readData = navm.bytecode.readData;

/// the VM
class NaVM{
private:
	/// TODO: instruction table
protected:
	void delegate()[] _instructions; /// instructions of loaded byte code
	NaData[] _arguments; /// argument of each instruction
	void delegate()* _inst; /// pointer to next instruction
	NaData* _arg; /// pointer to next instruction's arguments

public:
	/// constructor
	this(uinteger stackLength = 65_536){
	}
	/// destructor
	~this(){
	}
}