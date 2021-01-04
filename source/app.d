version(demo){
	import std.stdio;
	import navm.navm;

	import utils.misc : fileToArray;
	import std.datetime.stopwatch;


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
			string s = readln;
			s.length --; // remove \n char from end of string
			return NaData(s);
		}
		// ready the VM with these 4 external functions.
		NaVM vm = new NaVM([&writelnInt, &writelnDbl, &writeString, &readString]);
		// load the bytecode
		bool hasError = false;
		string[] errors = vm.load(fileToArray(args[1]));
		if (errors.length){
			writeln("Errors in byte code:");
			foreach (err; errors)
				writeln(err);
		}else{
			StopWatch sw;
			sw.start;
			// execute the function with id=0 (function defined first in bytecode), 
			// start with empty stack ([]). Put whatever you want to be on stack in second argument
			vm.execute(0);
			sw.stop;
			writeln("Execution finished in: ",sw.peek.total!"msecs", " msecs");
		}
	}
}