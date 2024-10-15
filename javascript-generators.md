---
title: JavaScript Generators
author: Travis Ennis
date: 2020-07-25
---

This is some background and references that I put together while developing my personal generator library, [travisennis/js-itertools](https://github.com/travisennis/js-itertools).

## Background

Generators and iterators are constructs that have long existed in many languages. I first ran into over 15 years go in Python and then discovered a similar language feature in F#. I found them to be powerful and useful tools. When they were first proposed for Javascript was way back in 2007 when they were proposed for ECMAScript 4, which was later abandoned. But at the time, a version of interators and generators existed that were very similar to Python's implementation and you could find them implemented both in Mozilla's Rhino and Spidermonkey Javascript engines. When I first implemented this library back in 2008 or 2009, I was mostly trying to copy the standard itertools library that could be found in Python so that I could use it for server-side scripting in Rhino. After ES4 was shelved, generators were redeveloped and the version of iterators and generators that exist today in Javascript is still very similar although a few things are different. The differences range from the minor, such as the `StopIteration` error being replaced by a `done` property that is on the object returned from a call to `next()`: `{done: true}`, to the major with the abandonment of generator expressions which were a concise and elegant way to construct new generators (I kind of miss these since they made is pretty trivial to port Python code that used generators into Javascript). What's left though is still extremely powerful.

Generators are not as well known as some other newer additions to the Javascript language, such as Promises and async/await, which had immediate and practical impacts on how many Javascript developers write code. Generators on the other hand are seemingly little used directly, although their inclusion in the language does make other, more well-known features, possible. For that reason they are worth knowing about, both in terms of how they work and how to use them.

If you have written a lot of Python, then you are probably familiar with most widely used generator in that language, the `range` function. It's the most widely used for good reason. You've probably seen the following in everywhere in Javascript:

```javascript
for(let i = 0; i < 100; i++) {
    console.log(i)
}
```

Using the range generator, the above code would be written as follows:

```javascript
for(let i of range(100)) {
    console.log(i)
}
```

The `range` function will start with 0 and return every number up to, but not including 100. If you want to start at 10, then you would write `range(10, 100)` and if you wanted to count by fives, then you would write `range(10, 100, 5)`. The `range` function is incredible versatile for writing loops. When looping through generator functions like this, what you are actually doing is calling the `next()` function on the generator itself. Without a loop you would interact with the generator like so:

```javascript
const r = range(10)
r.next() // {value: 0, done: false}
r.next() // {value: 1, done: false}
...
r.next() // {value: 9, done: true}
r.next() // {value: undefined, done: true}
```

The values the generator function returns, or yields, are generated each time the generator's `next()` method is called. There are some fairly interesting implications of this that need knowing. Let's say you write a generator function that counts numbers:

```javascript
const count = function * (start = 0, step = 1) {
  for (let i = start; true; i += step) {
    yield i
  }
}
```

This function won't allocate an infinite amount of numbers, but you could call `next()` on this generator and always get the next number, forever. A sequence this large doesn't take an infinite amount of memory since the values are generated as needed. But, before careful, because this:

```javascript
for(let i of count()) {
    console.log(i)
}
```

would result in an infinite loop. Because of this you must be aware if the generator you are using does or does not stop yielding values. You may ask why would you ever want a generator that effectively never stops, but there are uses. For example, an `enumerator()` generator written like so:

```javascript
const enumerate = function * (iterable) {
  yield * zip(count(), iterable)
}

const e = enumerate(range(0, 1000, 10))
console.log(e.next().value)
```

Would use count to enumerate the the amount of items in the providing iterable. The `zip` generator takes both iterables and returns a tuple (in current Javascript it is just a two element array) such as `[0, 0]`, `[1, 10]`, `[2, 20]`... `[100, 990]` and so on until the provided iterable is exhausted. No matter the length of the iterable we provide, `count()` will give us a value since it never ends.

Take a look at the references below. Generators are pretty fascinating in their own right and definitely worth learning.

### References

#### Documentation and Tutorials

- [Iterators and generators - JavaScript | MDN](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Iterators_and_Generators)
- [Understanding Generators in JavaScript | Tania Rascia](https://www.taniarascia.com/understanding-generators-in-javascript/)

#### Other Javascript Implementations

- [nvie/itertools.js: JavaScript port of Python's awesome itertools stdlib](https://github.com/nvie/itertools.js)
- [abozhilov/ES-Iter: Itertools for JavaScript](https://github.com/abozhilov/ES-Iter)

#### Python Generators

- [itertools — Functions creating iterators for efficient looping — Python Documentation](https://docs.python.org/3/library/itertools.html)
- [Functional Programming HOWTO — Python Documentation](https://docs.python.org/3/howto/functional.html)
