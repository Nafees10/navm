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
		ptrdiff_t _reg;
		/// register for compare result
		bool _regCmp;
		// instructions

		/// store	address
		void store(){
			_writeArg(_readArg!ptrdiff_t(), _reg);
		}
		/// load	address
		void load(){
			_reg = _readArg!ptrdiff_t(_readArg!ptrdiff_t());
		}
		/// load	ptrdiff_t
		void loadVal(){
			_reg = _readArg!ptrdiff_t();
		}
		/// print
		void print(){
			write(_reg);
		}
		/// print	char
		void printC(){
			write(_readArg!char());
		}
		/// print 	string
		void printS(){
			char[] str;
			str.length = _readArg!ptrdiff_t();
			_readArgArray(str);
			write(str);
		}
		/// add		address
		void add(){
			_reg += _readArg!ptrdiff_t(_readArg!ptrdiff_t());
		}
		/// add		ptrdiff_t
		void addVal(){
			_reg += _readArg!ptrdiff_t();
		}
		/// compare	address
		void compare(){
			_regCmp = _readArg!ptrdiff_t(_readArg!ptrdiff_t()) == _reg;
		}
		/// compare	ptrdiff_t
		void compareVal(){
			_regCmp = _readArg!ptrdiff_t() == _reg;
		}
		/// not
		void not(){
			_regCmp = !_regCmp;
		}
		/// jump	ptrdiff_t
		void jump(){
			immutable size_t labelIndex = _readArg!ptrdiff_t();
			if (labelIndex < _labelNames.length){
				_instIndex = _labelInstIndexes[labelIndex];
				_argIndex = _labelArgIndexes[labelIndex];
			}
		}
		/// jumpIf	ptrdiff_t
		void jumpIf(){
			immutable size_t labelIndex = _readArg!ptrdiff_t();
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
			immutable size_t count = args.length > 2 && args[2].isNum ? args[2].to!size_t : 1;
			StopWatch sw;
			sw = StopWatch(AutoStart.no);
			immutable ptrdiff_t startIndex = vm.labelNames.indexOf("start");
			if (startIndex == -1){
				writeln("label `start` not found");
				return;
			}
			size_t min = size_t.max ,max = 0 ,avg = 0;
			foreach (i; 0 .. count){
				sw.start;
				vm.execute(startIndex);
				sw.stop;
				immutable size_t currentTime = sw.peek.total!"msecs" - avg;
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