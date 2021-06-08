version(demo){
	import std.stdio;
	import std.datetime.stopwatch;
	import std.conv : to;

	import utils.misc;

	import navm.navm; // for the NaVM class
	import navm.bytecode; // for reading bytecode

	/// a VM
	class DemoVM : NaVM{
	private:
		/// general register
		integer _reg;
		/// register for compare result
		bool _regCmp;
		// instructions

		/// store	address
		void store(){
			integer addr;
			_readArg(addr);
			_writeArg(addr, _reg);
		}
		/// load	address
		void load(){
			_readArg(_reg);
			_readArg(_reg, _reg);
		}
		/// load	integer
		void loadVal(){
			_readArg(_reg);
		}
		/// print
		void print(){
			write(_reg);
		}
		/// print	char
		void printC(){
			char chr;
			_readArg(chr);
			write(chr);
		}
		/// print 	string
		void printS(){
			char[] str;
			integer len;
			_readArg(len);
			str.length = len;
			_readArgArray(str);
			write(str);
		}
		/// add		address
		void add(){
			integer i;
			_readArg(i);
			_readArg(i,i);
			_reg += i;
		}
		/// add		integer
		void addVal(){
			integer i;
			_readArg(i);
			_reg += i;
		}
		/// compare	address
		void compare(){
			integer i;
			_readArg(i);
			_readArg(i,i);
			_regCmp = i == _reg;
		}
		/// compare	integer
		void compareVal(){
			integer i;
			_readArg(i);
			_regCmp = i == _reg;
		}
		/// not
		void not(){
			_regCmp = !_regCmp;
		}
		/// jump	integer
		void jump(){
			uinteger labelIndex;
			_readArg(labelIndex);
			if (labelIndex < _labelNames.length){
				_instIndex = _labelInstIndexes[labelIndex];
				_argIndex = _labelArgIndexes[labelIndex];
			}
		}
		/// jumpIf	integer
		void jumpIf(){
			uinteger labelIndex;
			_readArg(labelIndex);
			if (_regCmp && labelIndex < _labelNames.length){
				_instIndex = _labelInstIndexes[labelIndex];
				_argIndex = _labelArgIndexes[labelIndex];
			}
		}
	public:
		/// constructor
		this(){
			super(); // this is a must, or create _instTable here manually
			NaInst[] instList = [
				NaInst("store", [NaInstArgType.Address]),
				NaInst("load", [NaInstArgType.Integer]),
				NaInst("load", [NaInstArgType.Address]),
				NaInst("print"),
				NaInst("print", [NaInstArgType.Char]),
				NaInst("print", [NaInstArgType.String]),
				NaInst("add", [NaInstArgType.Address]),
				NaInst("add", [NaInstArgType.Integer]),
				NaInst("compare", [NaInstArgType.Address]),
				NaInst("compare", [NaInstArgType.Integer]),
				NaInst("not"),
				NaInst("jump", [NaInstArgType.Label]),
				NaInst("jumpif",[NaInstArgType.Label]),
			];
			void delegate()[] ptrs = [
				&store,
				&loadVal,&load,
				&print,&printC,&printS,
				&add,&addVal,
				&compare,&compareVal,
				&not,
				&jump,&jumpIf,
			];
			foreach (i, ref inst; instList){
				if (_instTable.addInstruction(inst, ptrs[i]) == -1)
					throw new Exception("error adding instruction `"~inst.name~"`");
			}
		}
		/// loads bytecode
		/// 
		/// Returns: list of errors, if any
		override string[] loadBytecode(NaBytecode code){
			return this._loadBytecode(code);
		}
	}

	void main(string[] args){
		if (args.length < 2)
			args = [args[0], "sample"];
		DemoVM vm = new DemoVM();
		NaBytecode code = new NaBytecode(vm.instTable);
		string[] errors = code.load(fileToArray(args[1]));
		if (!errors.length)
			errors = vm.loadBytecode(code);
		if (errors.length){
			writeln("Errors in byte code:");
			foreach (err; errors)
				writeln(err);
		}else{
			immutable uinteger count = args.length > 2 && args[2].isNum ? args[2].to!uinteger : 1;
			StopWatch sw;
			sw = StopWatch(AutoStart.no);
			immutable integer startIndex = vm.labelNames.indexOf("start");
			if (startIndex == -1){
				writeln("label `start` not found");
				return;
			}
			uinteger min = uinteger.max ,max = 0 ,avg = 0;
			foreach (i; 0 .. count){
				sw.start;
				vm.execute(startIndex);
				sw.stop;
				immutable uinteger currentTime = sw.peek.total!"msecs" - avg;
				min = currentTime < min ? currentTime : min;
				max = currentTime > max ? currentTime : max;
				avg = sw.peek.total!"msecs";
			}
			avg = sw.peek.total!"msecs" / count;
			writeln("executed `",args[1],"` ",count," times:");
			writeln("min\tmax\tavg\ttotal");
			writeln(min,'\t',max,'\t',avg,'\t',sw.peek.total!"msecs");
		}
	}
}