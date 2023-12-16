module navm.bytecode;

import utils.ds;
import utils.misc;

import std.conv : to;
import std.algorithm : canFind;

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

	/// constructor, for instruction + args + comment
	this(string instName, string[] arguments=[], string comment = ""){
		this.instName = instName;
		this.arguments = arguments.dup;
		this.comment = comment;
	}
	/// constructor, for label + instruction
	this(string label, string instName, string[] arguments=[],
			string comment = ""){
		this.label = label;
		this.instName = instName;
		this.arguments = arguments.dup;
		this.comment = comment;
	}

	/// Reads statement from string
	void fromString(string statement){
		label = instName = null;
		arguments = null;
		string[] separated = statement.separateWhitespace;
		if (separated.length == 0)
			return;
		if (separated[0].length && separated[0][$-1] == ':'){
			this.label = separated[0][0 .. $-1];
			separated = separated[1 .. $];
			if (separated.length == 0)
				return;
		}
		if (separated[0].isAlphabet){
			this.instName = separated[0];
			separated = separated[1 .. $];
		}
		if (separated.length)
			this.arguments = separated;
	}

	/// Returns: string representation of this statement
	string toString() const {
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
	s.fromString("someInst arg1 # comment");
	assert(s == Statement("someInst", ["arg1"]), s.toString);
	s.fromString("load 0");
	assert(s == Statement("load", ["0"]));
}

/// stores data about available instruction
public struct NaInst{
	/// name of instruction, **in lowercase**
	string name;
	/// value when read as a ushort;
	ushort code = 0x0000;
	/// what type of arguments are expected
	NaInstArgType[] arguments;

	/// constructor
	this (string name, size_t code, NaInstArgType[] arguments = []){
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

/// Types of instruction arguments, for validation
public enum NaInstArgType : ubyte{
	Integer,		/// singed integer (ptrdiff_t)
	Double,			/// a double (float)
	Address,		/// Address to some argument
	String,			/// a string (char[])
	Label,			/// a label (name is stored)
	Char,				/// a 1 byte character
	Boolean,		/// boolean
}

/// For storing argument that is an Address
public struct NaInstArgAddress{
	string labelOffset; /// label, if any
	size_t address; /// the address itself

	/// constructor
	this (string labelOffset, size_t address = 0){
		this.labelOffset = labelOffset;
		this.address = address;
	}
	/// ditto
	this (size_t address){
		this.address = address;
	}
	/// ditto
	private this(ubyte[] binaryData){
		this._binData = binaryData;
	}

	/// Returns: this address, when stored as stream of bytes
	private @property ubyte[] _binData(){
		ubyte[] r;
		r.length = labelOffset.length + 8;
		r[] = 0;
		ByteUnion!size_t u = ByteUnion!size_t(address);
		debug{assert (u.array.length <= 8);}
		r[0 .. u.array.length] = u.array;
		r[8 .. $] = cast(ubyte[])labelOffset;
		return r;
	}

	/// ditto
	private @property ubyte[] _binData(ubyte[] newVal){
		labelOffset = [];
		address = 0;
		debug{assert (newVal.length >= 8);}
		immutable ByteUnion!size_t u = ByteUnion!size_t(newVal[0 .. size_t.sizeof]);
		address = u.data;
		if (newVal.length > 8)
			labelOffset = cast(string)newVal[8 .. $].dup;
		return newVal;
	}
}

/// For storing data of varying data types
public struct NaData{
	/// the actual data
	ubyte[] argData;

	/// value. ** do not use this for arrays, aside from string **
	///
	/// Returns: stored value, or `T.init` if invalid type
	@property T value(T)(){
		static if (is (T == string)){
			return cast(string)cast(char[])argData;
		} else static if (is (T == NaInstArgAddress)){
			return NaInstArgAddress(argData);
		} else {
			if (argData.length < T.sizeof)
				return T.init;
			return *(cast(T*)argData.ptr);
		}
	}
	/// ditto
	@property T value(T)(T newVal){
		static if (is (T == string)){
			argData.length = newVal.length;
			argData = cast(ubyte[])(cast(char[])newVal.dup);
			return newVal;
		}else static if (is (T == NaInstArgAddress)){
			argData = newVal._binData;
			return newVal;
		}else{
			if (argData.length >= T.sizeof){
				argData[0 .. T.sizeof] = (cast(ubyte*)&newVal)[0 .. T.sizeof];
				return newVal;
			}
			argData.length = T.sizeof;
			return this.value!T = newVal;
		}
	}
	/// constructor
	this(T)(T value){
		this.value!T = value;
	}
}
///
unittest{
	assert(NaData(cast(ptrdiff_t)1025).value!ptrdiff_t == 1025);
	assert(NaData("hello").value!string == "hello");
	assert(NaData(cast(double)50.5).value!double == 50.5);
	assert(NaData('a').value!char == 'a');
	assert(NaData(true).value!bool == true);
}

/// Stores bytecode
public class NaBytecode{
private:
	ushort[] _instCodes; /// codes of instructions
	NaData[] _instArgs; /// instruction arguments
	NaInstArgType[] _instArgTypes; /// instruction argument types
	size_t[2][] _labelIndexes; /// [codeIndex, argIndex] for each label index
	string[] _labelNames; /// label names
	NaInstTable _instTable; /// the instruction table
	bool _lastWasArgOnly; /// if last statement appended was args without instName
protected:

	/// Returns: size in bytes of argument at an index
	size_t argSize(size_t argIndex){
		if (argIndex > _instArgs.length)
			return 0;
		if (_instArgTypes[argIndex] == NaInstArgType.Address ||
				_instArgTypes[argIndex] == NaInstArgType.Integer ||
				_instArgTypes[argIndex] == NaInstArgType.Label)
			return ptrdiff_t.sizeof;
		else if (_instArgTypes[argIndex] == NaInstArgType.Boolean
				|| _instArgTypes[argIndex] == NaInstArgType.Char)
			return 1;
		else if (_instArgTypes[argIndex] == NaInstArgType.Double)
			return double.sizeof;
		else if (_instArgTypes[argIndex] == NaInstArgType.String)
			return  _instArgs[argIndex].value!string.length + ptrdiff_t.sizeof;
		return 0;
	}

	/// Changes labels to label indexes, and resolves addresses, in arguments
	///
	/// called by this.verify
	///
	/// Returns: false if there are invalid labels or addresses
	bool resolveArgs(){
		foreach (i; 0 .. _instArgs.length){
			// addresses: for now, change it to argument index.
			if (_instArgTypes[i] == NaInstArgType.Address){
				NaInstArgAddress addr = _instArgs[i].value!NaInstArgAddress;
				if (addr.labelOffset.length){
					immutable ptrdiff_t index = _labelNames.indexOf(addr.labelOffset);
					if (index == -1)
						return false;
					addr.address += _labelIndexes[index][1]; // TODO
					_instArgs[i].value!NaInstArgAddress = addr;
				}
				if (addr.address >= _instArgs.length)
					return false;
			}else if (_instArgTypes[i] == NaInstArgType.Label){
				// change label to label index
				immutable ptrdiff_t index = _labelNames.indexOf(_instArgs[i].value!string);
				if (index == -1)
					return false;
				_instArgs[i].value!ptrdiff_t = index;
			}
		}
		// now change addresses from indexes to addresses
		for(size_t i, labelIndex, size; i < _instArgs.length; i ++){
			if (_instArgTypes[i] == NaInstArgType.Address){
			size_t addressVal = 0;
				foreach (argIndex; 0 .. _instArgs[i].value!ptrdiff_t)
					addressVal += argSize(argIndex);
				_instArgs[i].value!ptrdiff_t = addressVal;
			}
			// if a label has this arg, change that too, this works assuming labels are in sorted order
			while (labelIndex < _labelIndexes.length && _labelIndexes[labelIndex][1] == i){
				_labelIndexes[labelIndex][1] = size;
				labelIndex ++;
			}
			size += argSize(i);
		}
		return true;
	}
public:
	/// constructor
	this(NaInstTable instructionTable){
		this._instTable = instructionTable;
		_lastWasArgOnly = false;
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
	@property NaData[] instArgs(){
		return _instArgs;
	}
	/// Returns: types of arguments for instructions
	@property NaInstArgType[] instArgTypes(){
		return _instArgTypes;
	}
	/// Returns: label indexes (`[instructionIndex, argIndex]`)
	@property size_t[2][] labelIndexes(){
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
		_lastWasArgOnly = false;
	}
	/// Verifies a loaded bytecode, to make sure only valid instructions exist, and correct number of arguments and types are loaded
	/// No more statements should be added after this has been called
	///
	/// Returns: true if verified without errors, false if there were errors.
	bool verify(string error){
		if (_labelNames.length != _labelIndexes.length || _instArgTypes.length != _instArgs.length){
			error = "labelNames and labelIndexes, and/or argumentTypes and arguments length mismatch";
			return false;
		}
		size_t argsInd;
		foreach (i; 0 .. _instCodes.length){
			NaInst inst;
			try
				inst = _instTable.getInstruction(_instCodes[i]);
			catch (Exception e){
				.destroy(e);
				error = "instruction with code "~_instCodes[i].to!string~" does not exist";
				return false;
			}
			if (_instArgs.length < argsInd || _instArgs.length - argsInd < inst.arguments.length){
				error = "not enough arguments for instruction `"~inst.name~"` with code "~inst.code.to!string;
				return false;
			}
			foreach (argInd; argsInd .. argsInd + inst.arguments.length){
				if (_instArgTypes[argInd] != inst.arguments[argInd - argsInd]){
					error = "invalid argument types for instruction `"~inst.name~"` with code "~inst.code.to!string;
					return false;
				}
			}
			argsInd += inst.arguments.length;
		}
		return resolveArgs();
	}
	/// ditto
	bool verify(){
		string dummyError;
		return verify(dummyError);
	}
	/// Adds a statement at end of existing bytecode
	///
	/// Returns: true if no errors, false if not done due to errors
	bool append(Statement statement, ref string error){
		if (statement.label.length){
			if (_labelNames.canFind(statement.label.lowercase)){
				error = "label `" ~ statement.label ~ "` used multiple times";
				return false;
			}
			_labelIndexes ~= [_instCodes.length, _instArgs.length];
			_labelNames ~= statement.label.lowercase;
		}
		if (statement.instName.length + statement.arguments.length == 0)
			return true;
		if (statement.instName.length && _lastWasArgOnly){
			error = "cannot add instruction after data section";
			return false;
		}
		if (!statement.instName.length && statement.arguments.length)
			_lastWasArgOnly = true;
		NaData[] args;
		NaInstArgType[] types;
		args.length = statement.arguments.length;
		types.length = args.length;
		foreach (index, arg; statement.arguments){
			try{
				args[index] = readData(arg, types[index]);
			}catch (Exception e){
				error ~= "argument `"~arg~"`: "~e.msg;
				.destroy(e);
				return false;
			}
		}
		if (statement.instName.length){
			immutable ptrdiff_t code = _instTable.getInstruction(statement.instName.lowercase, types);
			if (code == -1){
				error = "instruction does not exist or invalid arguments";
				return false;
			}
			_instCodes ~= cast(ushort)code;
		}
		_instArgs ~= args;
		_instArgTypes ~= types;
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
	/// Loads bytecode. Discards any existing bytecode
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
	/// ditto
	string[] load(string[] statementStrings){
		Statement[] statements;
		statements.length = statementStrings.length;
		foreach (i, line; statementStrings)
			statements[i].fromString(line);
		return load(statements);
	}
}
///
unittest{
	string[] source = [
		"start: instA l2",
		"	instB 50 50.5",
		"	instC \"hello\" false",
		"l2: instd 'c' start"
	];
	NaInstTable iTable = new NaInstTable();
	NaInst inst = NaInst("insta",[NaInstArgType.Label]);
	iTable.addInstruction(inst);
	inst = NaInst("instb", [NaInstArgType.Integer, NaInstArgType.Double]);
	iTable.addInstruction(inst);
	inst = NaInst("instc", [NaInstArgType.String, NaInstArgType.Boolean]);
	iTable.addInstruction(inst);
	inst = NaInst("instd", [NaInstArgType.Char, NaInstArgType.Label]);
	iTable.addInstruction(inst);
	NaBytecode bcode = new NaBytecode(iTable);
	bcode.load(source);
	assert(bcode.labelNames == ["start", "l2"]);
	assert(bcode.labelIndexes == [[0, 0], [3, 5]]);
	assert(bcode.instArgTypes == [NaInstArgType.Label, NaInstArgType.Integer, NaInstArgType.Double, NaInstArgType.String,
		NaInstArgType.Boolean, NaInstArgType.Char, NaInstArgType.Label]);
	assert(bcode.verify == true);
	.destroy(iTable);
	.destroy(bcode);
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
		_bin = new ByteStream();
	}
	~this(){
		.destroy(_bin);
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
		immutable size_t len = newVal.length > MAGIC_BYTES_IGNORE ? MAGIC_BYTES_IGNORE : newVal.length;
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
	/// Prepares binary bytecode. **call .verify() before this**
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
			_bin.write!ubyte(_instArgTypes[i], 1);
			_bin.writeArray(arg.argData, 8);
		}
		// labels
		_bin.write(_labelIndexes.length, 8); // number of labels
		foreach (i, label; _labelIndexes){
			_bin.write!size_t(label[0], 8); // code index
			_bin.write!size_t(label[1], 8); // instruction index
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
		size_t readCount;
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
		_metadata = _bin.readArray!ubyte(readCount, 8);
		if (readCount < _metadata.length)
			return false;
		// instruction codes
		_instCodes = _bin.readArray!ushort(readCount, 8);
		if (readCount < _instCodes.length)
			return false;
		// arguments
		_instArgs.length = _bin.read!size_t(incompleteRead,8);
		if (incompleteRead)
			return false;
		_instArgTypes.length = _instArgs.length;
		foreach(i; 0 .. _instArgs.length){
			_instArgTypes[i] = _bin.read!(NaInstArgType)(incompleteRead,1);
			instArgs[i].argData = _bin.readArray!ubyte(readCount, 8);
			if (readCount < instArgs[i].argData.length)
				return false;
		}
		// labels
		_labelIndexes.length = _bin.read!size_t(incompleteRead,8);
		if (incompleteRead)
			return false;
		_labelNames.length = _labelIndexes.length;
		foreach (i; 0 .. _labelIndexes.length){
			_labelIndexes[i][0] = _bin.read!size_t(incompleteRead, 8);
			if (incompleteRead)
				return false;
			_labelIndexes[i][1] = _bin.read!size_t(incompleteRead, 8);
			if (incompleteRead)
				return false;
			_labelNames[i] = cast(string)_bin.readArray!char(readCount, 8);
			if (readCount < _labelNames[i].length)
				return false;
		}
		return true;
	}
}
///
unittest{
	NaInstTable iTable = new NaInstTable();
	NaInst inst = NaInst("insta",[NaInstArgType.Label]);
	iTable.addInstruction(inst);
	inst = NaInst("instb", [NaInstArgType.Integer, NaInstArgType.Double]);
	iTable.addInstruction(inst);
	inst = NaInst("instc", [NaInstArgType.String, NaInstArgType.Boolean]);
	iTable.addInstruction(inst);
	inst = NaInst("instd", [NaInstArgType.Char, NaInstArgType.Label]);
	iTable.addInstruction(inst);
	NaBytecodeBinary binCode = new NaBytecodeBinary(iTable, cast(ubyte[])"test");
	bool status = true;
	status = status && binCode.append("start: instA end");
	status = status && binCode.append("instB 1025 1025.5");
	status = status && binCode.append("instc \"tab:\\tnewline:\\n\" true");
	status = status && binCode.append("end: instD 'c' start");
	assert(status == true); // all those functions returned true

	binCode.metadata = cast(ubyte[])"METADATA-metadata-0123456789";
	assert(binCode.verify());
	binCode.writeBinCode();
	binCode.binCode.toFile("tempcode");
	binCode.binCode.size = 0;
	binCode.metadata = [];
	binCode.binCode.fromFile("tempcode");
	assert(binCode.readBinCode() == true);
	assert(binCode.metadata == cast(ubyte[])"METADATA-metadata-0123456789");
	assert(binCode.instCodes == [1,2,3,4]);
	assert(binCode.instArgTypes == [NaInstArgType.Label, NaInstArgType.Integer, NaInstArgType.Double,
			NaInstArgType.String, NaInstArgType.Boolean, NaInstArgType.Char, NaInstArgType.Label]);
	assert(binCode.instArgs[0].value!ptrdiff_t == binCode.labelNames.indexOf("end"));
	assert(binCode.instArgs[1].value!ptrdiff_t == 1025);
	assert(binCode.instArgs[2].value!double == 1025.5);
	assert(binCode.instArgs[3].value!string == "tab:\tnewline:\n");
	assert(binCode.instArgs[4].value!bool == true);
	assert(binCode.instArgs[5].value!char == 'c');
	assert(binCode.instArgs[6].value!ptrdiff_t == binCode.labelNames.indexOf("start"));
	assert(binCode.labelNames == ["start", "end"]);
	.destroy(binCode);
	.destroy(iTable);
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
	ptrdiff_t addInstruction(ref NaInst inst, void delegate() ptr = null){
		if (inst.code == 0){
			// find code
			foreach (ushort i; 1 .. ushort.max){
				if (i ! in _instructions){
					inst.code = i;
					break;
				}
			}
			if (inst.code == 0)
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
	ptrdiff_t getInstruction(string name, NaInstArgType[] arguments){
		foreach (j, inst; _instructions){
			if (inst.name == name && inst.arguments.length == arguments.length){
				bool argsMatch = true;
				foreach (i; 0 .. arguments.length){
					if (inst.arguments[i] != arguments[i]){
						argsMatch = false;
						break;
					}
				}
				if (argsMatch)
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

/// Reads data from a string (which can be string, char, double, ptrdiff_t, bool)
///
/// Addresses are read as integers
///
/// Returns: the data in NaInstArg
///
/// Throws: Exception if data is invalid
public NaData readData(string strData, ref NaInstArgType type){
	NaData r;
	if (strData.length == 0)
		throw new Exception("cannot read data from empty string");
	if (["true", "false"].canFind(strData)){
		r.value!bool = strData == "true";
		type = NaInstArgType.Boolean;
	}else if (strData.isNum(false)){
		r.value!ptrdiff_t = strData.to!ptrdiff_t;
		type = NaInstArgType.Integer;
	}else if (strData.isNum(true)){
		r.value!double = strData.to!double;
		type = NaInstArgType.Double;
	}else if (strData.length >= 2 && (strData[0 .. 2] == "0x" || strData[0 .. 2] == "0B")){
		type = NaInstArgType.Integer;
		if (strData.length == 2)
			r.value!ptrdiff_t = 0;
		if (strData[0 .. 2] == "0x")
			r.value!ptrdiff_t = readHexadecimal(strData[2 .. $]);
		else
			r.value!ptrdiff_t = readBinary(strData[2 .. $]);
	}else if (strData[0] == '@'){
		type = NaInstArgType.Address;
		if (strData.length == 1)
			r.value!NaInstArgAddress = NaInstArgAddress(0);
		else if (strData[1 .. $].isNum(false))
			r.value!NaInstArgAddress = NaInstArgAddress(strData[1 .. $].to!ptrdiff_t);
		else{
			strData = strData[1 .. $];
			ptrdiff_t commaIndex = strData.indexOf(',');
			NaInstArgAddress addr;
			if (commaIndex == -1 && !strData.isNum(false)){
				addr.labelOffset = strData;
			}else{
				addr.labelOffset = strData[0 .. commaIndex].lowercase;
				if (commaIndex + 1 < strData.length){
					strData = strData[commaIndex + 1 .. $];
					if (strData.isNum(false))
						addr.address = strData.to!ptrdiff_t;
					else
						throw new Exception("invalid address");
				}
			}
			r.value!NaInstArgAddress = addr;
		}
	}else if (strData[0] == '\"'){
		type = NaInstArgType.String;
		r.value!string = strReplaceSpecial(strData[1 .. $-1]);
	}else if (strData[0] == '\''){
		type = NaInstArgType.Char;
		strData = strData.dup;
		strData = strReplaceSpecial(strData[1 .. $ -1]);
		if (strData.length > 1)
			throw new Exception("' ' can only contain 1 character");
		if (strData.length < 1)
			throw new Exception("no character provided in ''");
		r.value!char = strData[0];
	}else{
		// probably a label
		type = NaInstArgType.Label;
		r.value!string = strData.lowercase;
	}
	return r;
}
///
unittest{
	NaInstArgType type;
	assert("true".readData(type) == NaData(true));
	assert(type == NaInstArgType.Boolean);
	assert("false".readData(type) == NaData(false));
	assert(type == NaInstArgType.Boolean);

	assert("15".readData(type).value!ptrdiff_t == 15);
	assert(type == NaInstArgType.Integer);
	assert("0".readData(type).value!ptrdiff_t == 0);
	assert(type == NaInstArgType.Integer);
	assert("-1".readData(type).value!ptrdiff_t == -1);
	assert(type == NaInstArgType.Integer);
	assert("\"str\\t\"".readData(type).value!string == "str\t");
	assert(type == NaInstArgType.String);

	assert("potato".readData(type).value!string == "potato");
	assert(type == NaInstArgType.Label);

	assert("@1234".readData(type).value!NaInstArgAddress == NaInstArgAddress(1234));
	assert(type == NaInstArgType.Address);
	assert("@1234,12".readData(type).value!NaInstArgAddress == NaInstArgAddress("1234",12));
	assert(type == NaInstArgType.Address);
	assert("@label".readData(type).value!NaInstArgAddress == NaInstArgAddress("label"));
	assert(type == NaInstArgType.Address);
	assert("@label,1234".readData(type).value!NaInstArgAddress == NaInstArgAddress("label",1234));
	assert(type == NaInstArgType.Address);
}

/// reads a string into substrings separated by whitespace. Strings are read as a whole
///
/// Returns: substrings
///
/// Throws: Exception if string not closed
private string[] separateWhitespace(char[] whitespace=[' ','\t'], char comment='#')(string line){
	string[] r;
	for (size_t i, readFrom; i < line.length; i++){
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
			immutable ptrdiff_t endIndex = line.strEnd(i);
			if (endIndex < 0)
				throw new Exception("string not closed");
			r ~= line[readFrom .. endIndex+1].dup;
			readFrom = endIndex+1;
			i = endIndex;
			continue;
		}
		if (whitespace.canFind(c)){
			if (readFrom < i)
				r ~= line[readFrom .. i].dup;
			while (i < line.length && whitespace.canFind(line[i]))
				i ++;
			readFrom = i;
			i --; // back to whitespace, i++ in for(..;..;) exists
			continue;
		}
		if (i+1 == line.length && readFrom <= i){
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
private ptrdiff_t strEnd(char specialCharBegin='\\')(string s, size_t startIndex){
	size_t i;
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
	for (size_t i = 0; i < s.length; i ++){
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
