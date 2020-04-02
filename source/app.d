version(demo){
	import std.stdio;
	import navm.navm;

	import utils.misc : fileToArray;
	import std.datetime.stopwatch;


	void main(string[] args){
		NaData writelnInt(NaData[] args){
			foreach(arg; args){
				writeln(arg.intVal);
			}
			return NaData();
		}
		NaData writelnDbl(NaData[] args){
			foreach (arg; args){
				writeln(arg.doubleVal);
			}
			return NaData();
		}
		NaData writeString(NaData[] args){
			foreach (arg; args){
				write(arg.strVal);
			}
			return NaData();
		}
		NaData readString(NaData[] args){
			string s = readln;
			s.length --; // remove \n char from end of string
			return NaData(s);
		}
		// ready the VM with these 4 external functions.
		NaVM vm = new NaVM([&writelnInt, &writelnDbl, &writeString, &readString]);
		// load the bytecode
		bool hasError = false;
		try{
			vm.load(fileToArray(args[1]));
		}catch (Exception e){
			hasError = true;
			writeln("Error in bytecode:\n", e.msg);
		}

		if (!hasError){
			// execute the onLoad first
			vm.executeOnLoad();
			StopWatch sw;
			sw.start;
			// execute the function with id=0 (function defined first in bytecode), 
			// start with empty stack ([]). Put whatever you want to be on stack in second argument
			vm.execute(0, []);
			sw.stop;
			writeln("Execution finished in: ",sw.peek.total!"msecs", " msecs");
		}
	}
}