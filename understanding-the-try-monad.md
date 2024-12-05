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
        .unwrapOr(defaultUserData);
}
```

It's considerably different. Let's get into the details. 

## Core Implementation

The core structure of Try is implemented as an abstract class with two concrete implementations: Success and Failure:

```typescript
export abstract class Try<T> {
    abstract readonly isSuccess: boolean;
    abstract readonly isFailure: boolean;

    static success<T>(value: T): Try<T> {
        return new Success(value);
    }
    
    static failure<T>(error: Error): Try<T> {
        return new Failure(error);
    }
}

export class Success<T> extends Try<T> {
    readonly isSuccess: boolean = true;
    readonly isFailure: boolean = false;

    constructor(readonly value: T) {
        super();
    }
}

export class Failure<T> extends Try<T> {
    readonly isSuccess: boolean = false;
    readonly isFailure: boolean = true;

    constructor(readonly error: Error) {
        super();
    }
}
```

The abstract class defines the interface that both Success and Failure must implement, while the static factory methods `success` and `failure` ensure that developers create Try instances in a consistent way. This design makes it immediately clear whether you're dealing with a success or failure case when you see `Try.success` or `Try.failure` in the code.

The generic type parameter `T` allows Try to wrap any kind of value while maintaining type safety throughout operations. The Success class holds the actual value, while the Failure class contains an Error instance.

## State Inspection

The state inspection methods are now implemented as readonly properties and type guards:

```typescript
// Properties on Try instances
readonly isSuccess: boolean;
readonly isFailure: boolean;

// Type guard functions
export function isSuccess<T>(tryValue: Try<T>): tryValue is Success<T> {
    return tryValue.isSuccess;
}

export function isFailure<T>(tryValue: Try<T>): tryValue is Failure<T> {
    return tryValue.isFailure;
}
```

These properties and type guards are crucial for making decisions about how to process values and provide TypeScript with type information:

```typescript
const userProfile = await fetchUserProfile(userId);
if (isSuccess(userProfile)) {
    // TypeScript knows userProfile is Success<Profile> here
    renderProfile(userProfile.value);
} else {
    // TypeScript knows userProfile is Failure<Profile> here
    showErrorState();
    metrics.incrementCounter('profile_load_failures');
}
```

State inspection often precedes value extraction or serves as a branching point in business logic. For example, in a data processing pipeline:

```typescript
const processData = (input: string) => {
    const result = parseData(input);
    if (isFailure(result)) {
        // Handle the error early
        notifyAdmin('Data parsing failed');
        return defaultResponse();
    }
    
    // Continue with processing
    return transformData(result.unwrap());
};
```

## Value Extraction

The Value Extraction methods provide different ways to safely access the wrapped value in a Try instance:

```typescript
abstract unwrap(): T;
abstract unwrapOr(defaultValue: T): T;
abstract ok(): Option<T>;
abstract match<U>(pattern: {
    success: (value: T) => U;
    failure: (error: Error) => U;
}): U;
```

### unwrap: Direct Access with Risk

`unwrap` provides direct access to the success value but will throw if called on a failure. Use it when you're certain the Try contains a success value, typically after checking with `isSuccess`:

```typescript
const userAge = syncTry(() => getUserAge())
if (userAge.isSuccess) {
    // Safe to use unwrap here
    const age = userAge.unwrap();
    console.log(`User is ${age} years old`);
}
```

### unwrapOr: Safe Defaults

`unwrapOr` handles failure cases by providing a default value. This method never throws, making it ideal for situations where the computation should continue even if the original value is unavailable:

```typescript
// User settings with defaults
const settings = tryGetUserSettings(userId)
    .unwrapOr({
        theme: "light",
        fontSize: 12,
        language: "en"
    });

// Continue using settings regardless of success/failure
applyUserSettings(settings);
```

### match: Pattern Matching

`match` provides a powerful way to handle both success and failure cases in a single expression:

```typescript
const result = tryGetUserData(userId).match({
    success: (user) => `Welcome, ${user.name}!`,
    failure: (error) => `Failed to load user: ${error.message}`
});
```

Pattern matching is particularly useful when you need to transform both success and failure cases into a common type:

```typescript
interface ApiResponse {
    status: 'success' | 'error';
    data?: any;
    error?: string;
}

const response = tryFetchData().match({
    success: (data): ApiResponse => ({
        status: 'success',
        data
    }),
    failure: (error): ApiResponse => ({
        status: 'error',
        error: error.message
    })
});
```

### ok: Bridging Try and Option

`ok` creates a bridge between Try and Option types. While Try represents a computation that might fail with an error, Option represents a value that might not exist. This method transforms error cases into absent values while preserving success cases:

```typescript
const userPreferences = tryLoadPreferences().ok();

// userPreferences is now Option<Preferences>
// Instead of asking "did it fail?", we ask "is it present?"
if (userPreferences.isSome()) {
    applyPreferences(userPreferences.unwrap());
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
    welcomeUser(user.unwrap());
} else {
    showSignUpPrompt();
}
```

## Transformation Methods

The transformation methods enable complex operations while maintaining error handling context. Each method serves a specific purpose in data transformation pipelines:

```typescript
abstract map<U>(fn: (value: T) => U): Try<U>;
abstract flatMap<U>(fn: (value: T) => Try<U>): Try<U>;
abstract recover(fn: (error: Error) => T): Try<T>;
```

### map: Simple Transformations

`map` transforms success values while maintaining the Try context. It's ideal for simple transformations that don't involve error handling themselves:

```typescript
const userAge = parseUserData(rawData)
    .map(user => user.age)
    .map(age => age + 1)
    .map(age => `Age next year: ${age}`);
```

If the mapping function throws an error, it will be caught and wrapped in a Failure:

```typescript
const result = Try.success("123")
    .map(x => {
        throw new Error("Oops!");
        return parseInt(x);
    });
// result is Failure<number> containing the "Oops!" error
```

### flatMap: Complex Transformations

While `map` transforms values directly:
    `Try<A> -> (A -> B) -> Try<B>`

`flatMap` handles nested transformations:
    `Try<A> -> (A -> Try<B>) -> Try<B>`

`flatMap` handles operations that themselves return Try values. This prevents nested Try instances and maintains clean error handling:

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

If the recovery function throws, the Try will contain the new error:

```typescript
const result = Try.failure(new Error("First error"))
    .recover(error => {
        throw new Error("Recovery failed");
    });
// result is Failure containing "Recovery failed" error
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
    .unwrapOr(defaultData);
```

### asyncTry: Handling Promises

`asyncTry` wraps Promise-based operations, providing consistent error handling for asynchronous code:

```typescript
const userData = await asyncTry(fetch('/api/user'))
    .flatMap(response => 
        response.ok 
            ? asyncTry(response.json())
            : Try.failure(new Error('HTTP error'))
    )
    .match({
        success: data => ({ status: 'success', data }),
        failure: error => ({ 
            status: 'error',
            message: error.message 
        })
    });
```

## Serialization

Try instances can be serialized to JSON and converted to strings:

```typescript
const success = Try.success(42);
console.log(success.toString()); // "Try.success(42)"
console.log(JSON.stringify(success)); // {"type":"Try.success","value":42}

const failure = Try.failure(new Error("oops"));
console.log(failure.toString()); // "Try.failure(Error: oops)"
console.log(JSON.stringify(failure)); // {"type":"Try.failure","value":{}}
```

## When to Choose Try

Try is particularly valuable when:

1. You have a chain of operations that might fail
2. Error handling is part of your domain logic
3. You need to transform errors in a consistent way
4. You want to make error handling explicit in your API
5. You need to pattern match on success and failure cases

Avoid Try when:

1. You're dealing with simple, single-operation error handling
2. Performance is critical (Try adds a small overhead)
3. You need to handle multiple errors differently

## Testing Try-based Code

Try makes testing easier by making error paths explicit and providing type guards for precise type checking:

```typescript
describe('getUserData', () => {
    it('handles successful responses', async () => {
        const result = await getUserData('123');
        expect(isSuccess(result)).toBe(true);
        if (isSuccess(result)) {
            expect(result.value).toEqual(expectedData);
        }
    });

    it('handles network errors', async () => {
        const result = await getUserData('invalid');
        expect(isFailure(result)).toBe(true);
        expect(result.unwrapOr(defaultData)).toEqual(defaultData);
    });

    it('transforms data correctly', async () => {
        const result = await getUserData('123');
        const formatted = result.match({
            success: user => `User: ${user.name}`,
            failure: error => `Error: ${error.message}`
        });
        expect(formatted).toEqual('User: John');
    });
});
```

## Common Pitfalls

1. Using `unwrap` without checking:
```typescript
// Bad
const value = try.unwrap(); // Might throw

// Good
if (isSuccess(try)) {
    const value = try.unwrap();
}

// Better
const value = try.match({
    success: value => value,
    failure: error => defaultValue
});
```

2. Nested Try instances:
```typescript
// Bad
const nested = Try.success(Try.success(value));

// Good
const flat = Try.success(value)
    .flatMap(v => processValue(v));
```

3. Not using pattern matching when it would be clearer:
```typescript
// Less clear
let result;
if (isSuccess(try)) {
    result = processSuccess(try.value);
} else {
    result = handleError(try.error);
}

// Clearer
const result = try.match({
    success: value => processSuccess(value),
    failure: error => handleError(error)
});
```

## Practical Examples

Let's look at some real-world scenarios where Try shines:

### Parsing and Validating Configuration

```typescript
interface Config {
    port: number;
    host: string;
    timeout: number;
}

function loadConfig(path: string): Try<Config> {
    return syncTry(() => fs.readFileSync(path, 'utf8'))
        .flatMap(content => syncTry(() => JSON.parse(content)))
        .flatMap(json => validateConfig(json))
        .match({
            success: config => Try.success(config),
            failure: error => Try.success({
                port: 3000,
                host: 'localhost',
                timeout: 5000
            })
        });
}
```

### API Data Processing Pipeline

```typescript
interface UserData {
    id: string;
    profile: Record<string, unknown>;
}

async function processUserData(userId: string) {
    return await asyncTry(fetch(`/api/users/${userId}`))
        .flatMap(response => 
            response.ok 
                ? asyncTry(response.json())
                : Try.failure(new Error(`HTTP ${response.status}`))
        )
        .flatMap(data => validateUserData(data))
        .map(enrichUserData)
        .match({
            success: (data: UserData) => ({
                status: 'success',
                data,
                timestamp: new Date()
            }),
            failure: error => ({
                status: 'error',
                error: error.message,
                timestamp: new Date()
            })
        });
}
```

### Form Validation

```typescript
interface FormData {
    email: string;
    age: number;
}

function validateForm(input: unknown): Try<FormData> {
    return syncTry(() => {
        if (typeof input !== 'object' || !input) {
            throw new Error('Invalid input');
        }
        
        const { email, age } = input as Record<string, unknown>;
        
        if (typeof email !== 'string' || !email.includes('@')) {
            throw new Error('Invalid email');
        }
        
        if (typeof age !== 'number' || age < 0) {
            throw new Error('Invalid age');
        }
        
        return { email, age };
    });
}

const result = validateForm({ email: 'test@example.com', age: 25 })
    .map(data => enrichFormData(data))
    .match({
        success: data => ({ valid: true, data }),
        failure: error => ({ valid: false, error: error.message })
    });
```

## Conclusion

The Try monad transforms error handling from a necessary evil into a powerful tool for expressing business logic. It brings several key benefits:

First, it makes error handling explicit and impossible to ignore. Unlike promises that can swallow errors or try-catch blocks that can be forgotten, Try forces developers to make conscious decisions about error cases.

Second, it enables composition of operations that might fail. The transformation methods (`map`, `flatMap`, and `recover`) create clean pipelines that handle errors automatically, reducing boilerplate and improving code clarity.

Third, through pattern matching and the Option type bridge, Try provides flexibility in how errors are handled and transformed. Developers can choose whether to handle errors directly, convert them to optional values, or transform both success and failure cases into a common type.

For TypeScript developers, Try offers a path toward more maintainable codebases. It replaces scattered try-catch blocks with a consistent pattern that scales well as applications grow. When combined with other functional programming patterns, it forms part of a robust toolkit for handling complexity in modern applications.

The key to effective use of Try lies not just in understanding its mechanics, but in recognizing when to use each of its tools. Whether you need the strict error handling of `unwrap`, the safe defaults of `unwrapOr`, or the expressive power of pattern matching, Try provides the right tool for each situation.
