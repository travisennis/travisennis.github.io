---
title: Understanding the Try Monad in TypeScript
author: Travis Ennis
date: 2024-12-03
---

The Try monad represents computations that might fail. Instead of using traditional try-catch blocks, which can lead to imperative and harder-to-compose code, Try provides a functional approach to error handling. Originally popularized in Scala, Try wraps a value that either contains a successful result or an error, allowing developers to chain operations and handle errors in a consistent way. Before we get into the details, here is a comparison of try/catch error handling with Try.

```typescript
// Traditional approach
function getUserData(id: string) {
    try {
        const response = await fetch(`/api/users/${id}`);
        if (!response.ok) throw new Error('HTTP error');
        const data = await response.json();
        return processUserData(data);
    } catch (error) {
        logger.error(error);
        return defaultUserData;
    }
}

// Try-based approach
async function getUserData(id: string) {
    return await asyncTry(fetch(`/api/users/${id}`))
        .flatMap(response => 
            response.ok 
                ? asyncTry(response.json())
                : Try.failure(new Error('HTTP error'))
        )
        .map(processUserData)
        .getOrElse(defaultUserData);
}
```

It's considerably different. Let's get into the details. 

## Core Implementation

The core structure of Try wraps a value that might be either a success or a failure:

```typescript
export class Try<T> {
    private constructor(private value: T | Error) {}
    
    static success<T>(value: T): Try<T> {
        return new Try(value);
    }
    
    static failure<T>(error: Error): Try<T> {
        return new Try<T>(error);
    }
}
```

The private constructor ensures that developers can only create Try instances through `success` and `failure` factory methods. This prevents invalid states and ensures consistent initialization, but perhaps the most important reason it is written this way is that when you see `Try.success` and `Try.failure` in the code there is no ambiguity about which is the succcess path and which is not. 

The generic type parameter `T` allows Try to wrap any kind of value while maintaining type safety throughout operations. Inside the class, the value is stored as a union type `T | Error`. This internal representation stays hidden from users, preventing direct access to potentially unsafe values.

## State Inspection

The state inspection methods provide the foundation for working with Try values:

```typescript
isSuccess(): boolean {
    return !(this.value instanceof Error);
}

isFailure(): boolean {
    return this.value instanceof Error;
}
```

These methods determine whether a Try instance represents a success or failure state. While simple, they're crucial for making decisions about how to process values:

```typescript
const userProfile = await fetchUserProfile(userId);
if (userProfile.isSuccess()) {
    renderProfile(userProfile.unsafeGet());
} else {
    showErrorState();
    metrics.incrementCounter('profile_load_failures');
}
```

State inspection often precedes value extraction or serves as a branching point in business logic. For example, in a data processing pipeline:

```typescript
const processData = (input: string) => {
    const result = parseData(input);
    if (result.isFailure()) {
        // Handle the error early
        notifyAdmin('Data parsing failed');
        return defaultResponse();
    }
    
    // Continue with processing
    return transformData(result.unsafeGet());
};
```

## Value Extraction

The Value Extraction methods form the core interface for working with Try values. Each method addresses specific use cases and trade-offs in error handling:

```typescript
unsafeGet(): T {
    if (this.isFailure()) {
        throw new Error("Cannot get value from a failed Try");
    }
    return this.value as T;
}

getOrElse(defaultValue: T): T {
    return this.isSuccess() ? (this.value as T) : defaultValue;
}

getOrThrow(): T {
    if (this.isFailure()) {
        throw this.value;
    }
    return this.value as T;
}

ok() {
  if (this.isFailure()) {
    return Option.none<T>();
  }
  return Option.some<T>(this.value as T);
}

failSilently(callback: (e: Error) => void) {
    if (this.isFailure()) {
        callback(this.value as Error);
        return Option.none<T>();
    }
    return Option.some<T>(this.value as T);
}
```

### unsafeGet: Direct Access with Risk

`unsafeGet` provides direct access to the success value. The "unsafe" prefix serves as a warning: this method will throw if called on a failure. Use it when you're certain the Try contains a success value, typically after checking with `isSuccess()`:

```typescript
const userAge = syncTry(() => getUserAge())
if (userAge.isSuccess()) {
    // Safe to use unsafeGet here
    const age = userAge.unsafeGet();
    console.log(`User is ${age} years old`);
}
```

### getOrElse: Safe Defaults

`getOrElse` handles failure cases by providing a default value. This method never throws, making it ideal for situations where the computation should continue even if the original value is unavailable:

```typescript
// User settings with defaults
const settings = tryGetUserSettings(userId)
    .getOrElse({
        theme: "light",
        fontSize: 12,
        language: "en"
    });

// Continue using settings regardless of success/failure
applyUserSettings(settings);
```

### getOrThrow: Error Propagation

`getOrThrow` is similar to `unsafeGet` but throws the original error instead of a new one. This preserves the error stack trace and context, making it valuable for error reporting and debugging:

```typescript
try {
    const data = parseConfigFile()
        .flatMap(validateConfig)
        .getOrThrow();
    // Use validated config
} catch (error) {
    // Error maintains its original context
    reportError("Config validation failed", error);
}
```

### ok: Bridging Try and Option

`ok` creates a bridge between Try and Option types. While Try represents a computation that might fail with an error, Option represents a value that might not exist. This method transforms error cases into absent values while preserving success cases:

This transformation is useful when you need to:
1. Log or track errors without throwing them
2. Convert error states into missing values
3. Switch from error-centric to presence-centric logic

Consider this example:

```typescript
const userPreferences = tryLoadPreferences().ok();

// userPreferences is now Option<Preferences>
// Instead of asking "did it fail?", we ask "is it present?"
if (userPreferences.isSome()) {
    applyPreferences(userPreferences.get());
} else {
    useDefaultPreferences();
}
```

The shift from Try to Option changes how we think about the value. Try focuses on success/failure, while Option focuses on presence/absence. This distinction becomes important in domain modeling:

```typescript
// Error-focused approach with Try
const tryGetUser = (id: string): Try<User> => {
    if (invalidId(id)) {
        return Try.failure(new Error("Invalid ID"));
    }
    return Try.success(loadUser(id));
};

// Presence-focused approach with Option
const findUser = (id: string): Option<User> => {
    return tryGetUser(id).ok();
};

// Usage focuses on presence rather than errors
const user = findUser(id);
if (user.isSome()) {
    welcomeUser(user.get());
} else {
    showSignUpPrompt();
}
```

### failSilently: ok with a callback

`failSilently` is like `ok` but with a callback that will be executed on the failure path. This allows for things like logging or metrics to be done when errors are encountered:

```typescript
const userPreferences = tryLoadPreferences()
    .failSilently(error => {
        analytics.trackError("preferences_load_failed", error);
    });

// userPreferences is now Option<Preferences>
// Instead of asking "did it fail?", we ask "is it present?"
if (userPreferences.isSome()) {
    applyPreferences(userPreferences.get());
} else {
    useDefaultPreferences();
}
```

## Transformation Methods

The transformation methods enable complex operations while maintaining error handling context. Each method serves a specific purpose in data transformation pipelines:

```typescript
map<U>(f: (value: T) => U): Try<U> {
    if (this.isFailure()) {
        return Try.failure(this.value as Error);
    }
    try {
        return Try.success(f(this.value as T));
    } catch (e) {
        return Try.failure(e instanceof Error ? e : new Error(String(e)));
    }
}

flatMap<U>(f: (value: T) => Try<U>): Try<U> {
    if (this.isFailure()) {
        return Try.failure(this.value as Error);
    }
    try {
        return f(this.value as T);
    } catch (e) {
        return Try.failure(e instanceof Error ? e : new Error(String(e)));
    }
}

recover(f: (error: Error) => T): Try<T> {
    if (this.isSuccess()) {
        return this;
    }
    try {
        return Try.success(f(this.value as Error));
    } catch (e) {
        return Try.failure(e instanceof Error ? e : new Error(String(e)));
    }
}
```

### map: Simple Transformations

`map` transforms success values while maintaining the Try context. It's ideal for simple transformations that don't involve error handling themselves:

```typescript
const userAge = parseUserData(rawData)
    .map(user => user.age)
    .map(age => age + 1)
    .map(age => `Age next year: ${age}`);
```

### flatMap: Complex Transformations

While `map` transforms values directly:
    `Try<A> -> (A -> B) -> Try<B>`

`flatMap` handles nested transformations:
    `Try<A> -> (A -> Try<B>) -> Try<B>`

`flatMap` handles operations that themselves return Try values. This prevents nested Try instances and maintains clean error handling.

This is crucial when you have operations that might fail in your Try chain:

```typescript
// With map (leads to Try<Try<User>>):
const result = Try.success(userId)
    .map(id => fetchUser(id)); // fetchUser returns Try<User>

// With flatMap (gives Try<User>):
const result = Try.success(userId)
    .flatMap(id => fetchUser(id));
```

### recover: Error Recovery

`recover` provides a way to handle errors by attempting to produce a valid value:

```typescript
const userSettings = loadUserSettings(userId)
    .recover(error => {
        logger.warn(`Failed to load settings: ${error.message}`);
        return getDefaultSettings();
    });
```

## Utility Functions

The utility functions provide convenient ways to create Try instances from both synchronous and asynchronous operations:

```typescript
export function syncTry<T>(f: () => T): Try<T> {
    try {
        return Try.success(f());
    } catch (e) {
        return Try.failure(e instanceof Error ? e : new Error(String(e)));
    }
}

export async function asyncTry<T>(promise: Promise<T>): Promise<Try<T>> {
    try {
        const result = await promise;
        return Try.success(result);
    } catch (e) {
        return Try.failure(e instanceof Error ? e : new Error(String(e)));
    }
}
```

### syncTry: Wrapping Synchronous Operations

Use `syncTry` for operations that might throw errors:

```typescript
const parsedData = syncTry(() => JSON.parse(rawData))
    .map(data => processData(data))
    .getOrElse(defaultData);
```

### asyncTry: Handling Promises

`asyncTry` wraps Promise-based operations, providing consistent error handling for asynchronous code:

```typescript
const userData = await asyncTry(fetch('/api/user'))
    .flatMap(response => syncTry(() => response.json()))
    .recover(error => ({ 
        status: 'error',
        message: error.message 
    }));
```

## When to Choose Try

Try is particularly valuable when:

1. You have a chain of operations that might fail
2. Error handling is part of your domain logic
3. You need to transform errors in a consistent way
4. You want to make error handling explicit in your API

Avoid Try when:

1. You're dealing with simple, single-operation error handling
2. Performance is critical (Try adds a small overhead)
3. You need to handle multiple errors differently

## Testing Try-based Code

Try makes testing easier by making error paths explicit:

```typescript
describe('getUserData', () => {
    it('handles successful responses', async () => {
        const result = await getUserData('123');
        expect(result.isSuccess()).toBe(true);
        expect(result.unsafeGet()).toEqual(expectedData);
    });

    it('handles network errors', async () => {
        const result = await getUserData('invalid');
        expect(result.isFailure()).toBe(true);
        expect(result.getOrElse(defaultData)).toEqual(defaultData);
    });
});
```

## Common Pitfalls

1. Overuse of `unsafeGet`:
```typescript
// Bad
const value = try.unsafeGet(); // Might throw

// Good
const value = try.getOrElse(defaultValue);
```

2. Nested Try instances:
```typescript
// Bad
const nested = Try.success(Try.success(value));

// Good
const flat = Try.success(value)
    .flatMap(v => processValue(v));
```

3. Mixing Try with traditional try-catch:
```typescript
// Bad
try {
    const result = someOperation()
        .getOrThrow();
} catch (e) {
    // This defeats the purpose of using Try
}

// Good
const result = someOperation()
    .recover(error => handleError(error));
```

## Practical Examples

Let's look at some real-world scenarios where Try shines:

### Parsing JSON
```typescript
const parseJSON = (input: string) => syncTry(() => JSON.parse(input))
    .map(data => data.username)
    .getOrElse("anonymous");

// Success case
const result1 = parseJSON('{"username": "john"}'); // "john"
// Failure case
const result2 = parseJSON('invalid json'); // "anonymous"
```

### API Calls
```typescript
async function fetchUserData(userId: string) {
    const response = await asyncTry(fetch(`/api/users/${userId}`));
    const result = response
        .flatMap(r => syncTry(() => r.json() as Promise<Record<string, string>>))
        .recover(error => Promise.resolve({ name: "Unknown", error: error.message }));

    return result;
}
```

### Chaining Operations
```typescript
type User = Record<string, string>;

interface Body {
    user: User;
}

function validateUser(user: User): Try<User> {
    if (user.test) {
        return Try.failure(new Error("invalid"));
    }
    return Try.success(user);
}

function formatUserData(user: User) {
    return user.toString();
}

function processUserData(input: string) {
    return syncTry(() => JSON.parse(input) as Body)
        .map(data => data.user)
        .flatMap(user => validateUser(user))
        .map(user => formatUserData(user))
        .failSilently(error => console.log(`Processing failed: ${error.message}`));
}
```

### Configuration Loading

```typescript
const loadConfig = (path: string) => {
    return syncTry(() => fs.readFileSync(path, 'utf8'))
        .flatMap(content => syncTry(() => JSON.parse(content)))
        .recover(error => ({
            // Provide sensible defaults on failure
            port: 3000,
            host: 'localhost',
            error: `Failed to load config: ${error.message}`
        }));
};
```

## Conclusion

The Try monad transforms error handling from a necessary evil into a powerful tool for expressing business logic. It brings several key benefits:

First, it makes error handling explicit and impossible to ignore. Unlike promises that can swallow errors or try-catch blocks that can be forgotten, Try forces developers to make conscious decisions about error cases.

Second, it enables composition of operations that might fail. The transformation methods (`map`, `flatMap`, and `recover`) create clean pipelines that handle errors automatically, reducing boilerplate and improving code clarity.

Third, through its integration with Option via `failSilently`, Try provides flexibility in how errors are conceptualized. Developers can choose whether to treat missing data as an error condition or simply as an absent value, depending on what makes more sense for their domain.

For TypeScript developers, Try offers a path toward more maintainable codebases. It replaces scattered try-catch blocks with a consistent pattern that scales well as applications grow. When combined with other functional programming patterns, it forms part of a robust toolkit for handling complexity in modern applications.

The key to effective use of Try lies not just in understanding its mechanics, but in recognizing when to use each of its tools. Whether you need the strict error handling of `getOrThrow`, the safe defaults of `getOrElse`, or the presence-absence semantics of `failSilently`, Try provides the right tool for each situation.
