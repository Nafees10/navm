version(demo){
	import std.stdio;
	import navm.navm;

	import utils.misc;
	import std.datetime.stopwatch;
	import std.conv : to;

	void main(string[] args){
		if (args.length < 2)
			args = [args[0], "sample"];
		string[] errors;
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
				// start execution at instruction at index=0
				sw.stop;
				times[i] = sw.peek.total!"msecs";
				sw.reset;
				writeln("Execution finished in: ",times[i], " msecs");
				min = times[i] < min ? times[i] : min;
				max = times[i] > max ? times[i] : max;
				avg += times[i];
			}
			avg = avg / count;
			if (count > 1){
				writeln("min\tmax\tavg");
				writeln(min,'\t',max,'\t',avg);
			}
		}
	}
}