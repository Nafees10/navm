version(demo){
	import std.stdio;
	import navm.navm;

	import utils.misc;
	import std.datetime.stopwatch;
	import std.conv : to;


	void main(string[] args){
		if (args.length < 2)
			args = [args[0], "sample"];
		NaData writelnInt(NaData[] _args){
			foreach(arg; _args){
				writeln(arg.intVal);
			}
			return NaData();
		}
		NaData writelnDbl(NaData[] _args){
			foreach (arg; _args){
				writeln(arg.doubleVal);
			}
			return NaData();
		}
		NaData writeString(NaData[] _args){
			foreach (arg; _args){
				write(arg.strVal);
			}
			return NaData();
		}
		NaData readString(NaData[]){
			dstring s = (readln).to!dstring;
			if (s[$-1] == '\n')
				s = s[0..$-1];
			return NaData(s);
		}
		void dummyInstruction(){
			writeln("dummy instruction called");
		}
		// ready the VM with these 4 external functions.
		NaVM vm = new NaVM([&writelnInt, &writelnDbl, &writeString, &readString]);
		vm.addInstruction(NaInstruction("dummyInstruction", 0xFF,false,false,0,0,&dummyInstruction));
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