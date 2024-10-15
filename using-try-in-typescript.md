---
title: Using Try in Typescript
author: Travis Ennis
date: 2024-10-13
---

The Try type is a programming construct used to represent the result of an operation that can either succeed or fail. It encapsulates a value of a specific type (T) if the operation succeeds, or an error (E) if the operation fails. This type is particularly useful in functional programming and error handling, as it allows functions to return results that clearly indicate success or failure without relying on exceptions or special return code. I originally came across the concept in Scala.

The benefits of the Try type are:

- **Explicit Error Handling:** Using Try makes error handling explicit. Callers of a function that returns a Try type must handle both success and failure cases.
- **Immutability:** Try types are immutable, which fits well with functional programming principles.
- **Functional Composition:** Try types can be easily composed using functional methods like map, flatMap, recover, etc., allowing for clean and readable error-handling code.

In Typescript the Try type could be represented as simply as:

```typescript
type Try<T, E extends Error = Error> = T | E;
```

From that base type, we can build a simple API on top of it for working with Try's in a Typescript code base.

- **asyncTry** and **syncTry**: Functions that execute asynchronous and synchronous operations, respectively, and return a Try type.
- **getOrDefault** and **getOrElse**: Functions to extract the value from a Try, providing a default value or a default function to handle errors.

Let's look at the implementation of those:

```typescript
async function asyncTry<T, E extends Error = Error>(
  input: PromiseLike<T>,
): Promise<Try<T, E>> {
  try {
    const v = await input;
    
    return v;
  } catch (err) {
    return err as E;
  }
}
  
function syncTry<T, E extends Error = Error>(input: () => T): Try<T, E> {
  try {
    const v = input();
      
    return v;
  } catch (err) {
    return err as E;
  }
}      

function getOrDefault<T, E extends Error = Error>(
  input: Try<T, E>,
  defaultValue: T,
): T {
  if (input instanceof Error) {
    return defaultValue;
  }
  return input;
}

function getOrElse<T, E extends Error = Error>(
  input: Try<T, E>,
  defaultFn: () => T,
): T {
  if (input instanceof Error) {
    return defaultFn();
  }
  return input;
}    
```

So how do these functions get used. The best way to show that is to start with how error handling would be done without them. Let starts with two functions, one async, fetchData, and one synchronous, parseJSON.

```typescript
async function fetchData(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error("Network response was not ok");
  }
  return response.text();
}

function parseJSON(jsonString: string): any {
  return JSON.parse(jsonString);
}
```

Both of these functions could throw errors. Javascript as a language has no concept such as checked exceptions, so nothing about the return type of either function is going to tell if it does throw a function. Consequentlyl, many developers err on the side of caution and wrap the functions in a try/catch. Many times, the entire block is wrapped in a single try/catch.

```typescript
try {
  const result = await fetchData("https://api.example.com/data");
  const jsonObj = parseJSON(result);
  console.dir(jsonObj);
}
catch (err) {
  console.err(err);
}
```

This code is fine, but it is not particularly flexible. If I wanted to do somethign different on the error from fetchData than I did on parseJSON, then it would look like this:

```typescript
let result;
try {
  result = await fetchData("https://api.example.com/data");
}
catch (err) {
  console.err(err);
}

try{
  if(result) {
    const jsonObj = parseJSON(result);
    console.dir(jsonObj);
  }
}
catch (err) {
  console.err(err);
  // soething else
}
```

Notice how this change results in the variable, result, going from a const to let and then having to check to see if result is undefined before calling parseJSON. Try will allow to fix those problem, while also making making checking for an error something that can be caught as type error by the compiler.

```typescript
const result = await asyncTry(fetchData("https://api.example.com/data"));
if (!(result instanceof Error)) {
  const jsonObj = syncTry(() => parseJSON(result));
  if (jsonObj instanceof Error) {
    console.error("Failed to parse JSON:", jsonObj.message);
  } else {
    console.log("Parsed JSON:", jsonObj);
  }
}
```

With this we get back the const and the type system forces us to deal with the errors. It might be a bit more verbose, but it is much safer.

So, let's quickly look at some examples of getOrDefault and getOrElse.

```typescript
const defaultValue = "default value";

const successResult: Try<string> = "successful result";
const errorResult: Try<string> = new Error("An error occurred");

console.log(getOrDefault(successResult, defaultValue)); // Output: "successful result"
console.log(getOrDefault(errorResult, defaultValue)); // Output: "default value"
```

and

```typescript
const defaultFn = () => "default value from function";

const successResult: Try<string> = "successful result";
const errorResult: Try<string> = new Error("An error occurred");

console.log(getOrElse(successResult, defaultFn)); // Output: "successful result"
console.log(getOrElse(errorResult, defaultFn)); // Output: "default value from function"
```

Put it all together and you get:

```typescript
const asyncResult = await asyncTry(fetchData("https://api.example.com/data"));

const result = getOrDefault(asyncResult, "{}");
const parsedResult = syncTry(() => parseJSON(result));

const finalResult = getOrElse(
  parsedResult,
  () => {}
);

console.log("Async result:", asyncResult instanceof Error ? asyncResult.message : asyncResult);
console.log("Final result:", finalResult);
```

Hopefully you can see the power of Try and how it can imporove your error handling and make your code safer.
