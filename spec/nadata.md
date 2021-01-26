# NaData

Data passed to instructions is of data type `NaData` struct.  
It contains an anonymous union of:  

* `bool boolVal;`
* `dchar dcharVal;`
* `utils.misc.integer intVal;`
* `double doubleVal;`
* `NaData* ptrVal;`

booleans, dchar, int/long, doubles, and references (pointers) are stored using above types.  

## Arrays:

Arrays are stored using the `NaData.ptrVal` pointer. This pointer points to the second element in an array, where the first element is the length of the rest of the array.  
However, rather than reading it like that, you can simply use the following functions for using arrays:  

* `NaData.makeArray` to initialize an array.
* `NaData.arrayVal [setter/getter]` to modify the array.
* `NaData.arrayValLength [setter/getter]` to modify the length or get the length of array. `makeArray` **must** be called before using these.

## Strings:

Strings are just regular arrays as defined above. You can use these functions to use arrays as a dchar array:  

* `NaData.strVal [setter/getter]` set or get the string as a `dchar[]`.
