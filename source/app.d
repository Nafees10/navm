version(demo){
	import std.stdio;
	import navm.navm;

	import utils.misc;
	import std.datetime.stopwatch;
	import std.conv : to;

	/// inherited VM with instruction added that we need
	class VM : NaVM{
	protected:
		void writeStr(){
			write(_stack.pop.strVal);
		}
		void writeInt(){
			write(_stack.pop.intVal);
		}
		void writeDouble(){
			write(_stack.pop.doubleVal);
		}
	public:
		/// constructor
		this(){
			super();
			addInstruction(NaInstruction("writeInt",0xF0,1,0,&writeInt));
			addInstruction(NaInstruction("writeStr",0xF1,1,0,&writeStr));
			addInstruction(NaInstruction("writeDouble",0xF2,1,0,&writeDouble));
		}
	}


	void main(string[] args){
		if (args.length < 2)
			args = [args[0], "sample"];
			
		NaVM vm = new VM();
		// load the bytecode
		string[] errors = vm.load(fileToArray(args[1]));
		if (errors.length){
			writeln("Errors in byte code:");
			foreach (err; errors)
				writeln(err);
		}else{
			immutable uinteger count = args.length > 2 && args[2].isNum ? args[2].to!uinteger : 1;
			StopWatch sw;
			uinteger[] times;
			times.length = count;
			uinteger min,max,avg;
			min = uinteger.max;
			foreach (i; 0 .. count){
				sw.start;
				vm.execute(0); // start execution at instruction at index=0
				sw.stop;
				times[i] = sw.peek.total!"msecs";
				sw.reset;
				writeln("Execution finished in: ",times[i], " msecs");
				min = times[i] < min ? times[i] : min;
				max = times[i] > max ? times[i] : max;
				avg += times[i];
			}
			avg = avg / count;
			writeln("min\tmax\tavg");
			writeln(min,'\t',max,'\t',avg);
		}
	}
}