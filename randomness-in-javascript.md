---
title: Randomness in JavaScript
author: Travis Ennis
date: 2020-11-22
---

As I started to learn to code generative art, I came to realize that randomness is a huge part of the toolset. Most of the generative art I have written relies on randomness throughout the code; I'll use randomness to pick my inputs, or choose my color palette, or alter the program's execution. Randomness is so central to generative art that I have spent the last seveal months trying to understand it better. What folllows is brief introduction of random number generation in JavaScript.

JavaScript provides a standard function, `Math.random`, that is defined in the [ECMAScript Specification](http://www.ecma-international.org/ecma-262/11.0/index.html#sec-math.random). It takes no arguments and returns a positive number from 0 up to but not including 1. For most purposes, `Math.random` is fine, but it does have its drawbacks. First, its algorithm is not defined and can vary from implementation to implementation. In practice, it seems that the major browsers and V8/Node have settled on `xorshift128+` as the algorithm, but that is not guaranteed (see [There’s Math.random(), and then there’s Math.random() · V8](https://v8.dev/blog/math-random)). Second, `Math.random` is not cryptographically secure. In most cases, one doesn't need a cryptographically secure PRNG, but if you do, then `Math.random` is not for you. In browsers, this deficiency has been addressed with `window.crypto.getRandomValues`. You could create an equivalent of `Math.random` that is backed by this API roughly like so:

``` javascript
function secureRandom() {
    const arr = new Uint32Array(1)
    windows.crypto.getRandomValues(arr)
    return arr[0] / 4294967296
}
```

In reality you would never do this. This would be much less performant than a simple call to `Math.random` and unless you are doing hashing, signature generation, or encryption/decryption, there is little need for it. And it still suffers from the third issue with built-in random function in JavaScript - no ability to repeat sequences.

All random number generators are pseudo-random number generators, which means they generate sequences of numbers based on algorithm that alters an intial seed. With a different seed, you get a different sequence, but with the same seed the random number generator will repeat the same sequence every time. Unfortuantely you can't seed the built-in `Math.random` or `window.crypto.getRandomValues`. You might ask why you would want to control the seed of the algorithm, but sometimes you need a complex seed to make your random sequence less predictable and sometimes you need a sequence that is completely predictable. This is frequently the case in generative art when you would want to recreate a piece of art. That predictability comes from being able to provide the seed. There are many seedable random number generators available in JavaScript:

- [davidbau/seedrandom: seeded random number generator for Javascript](https://github.com/davidbau/seedrandom)
- [Pseudorandom number generators](https://github.com/bryc/code/blob/master/jshash/PRNGs.md)
- [Better Random Numbers for Javascript](https://github.com/nquinlan/better-random-numbers-for-javascript-mirror)

In generative art libraries, there have been several choices made:

- [p5.js](https://p5js.org/) uses `LCG`
- [three.js](https://threejs.org/) uses the Park-Miller algorithm for a seedable PRNG, but otherwise uses `Math.random`
- [q5xjs](https://github.com/LingDong-/q5xjs) uses `Alea`

Which you choose are largely based on your use case, but for me I typically turn to the `mulberry32` implementation:

``` javascript
function mulberry32(a) {
    return function() {
      a |= 0; a = a + 0x6D2B79F5 | 0;
      var t = Math.imul(a ^ a >>> 15, 1 | a);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    }
}
```

It's a minimalistic, 32-bit implemtentation that is pretty fast in JavaScript and has good randomness. And despite being 32-bit, its period (how long the random sequence goes before repeating) is still fairly large at around 4 billion. An 128-bit algorithm would have a larger period, but I don't have a need for sequences that large.

Once you have a seedable PRNG implementation, you have to choose how to generate a seed. At this point I base my strategy for selecting a seed on this article, [How to select a seed for simulation or randomization | R-bloggers](https://www.r-bloggers.com/how-to-select-a-seed-for-simulation-or-randomization/), as it seems a good enough strategy as any. In JavaScript, the code would be:

``` javascript
const seed = Date.now() % 10000
```

but if you want to go further, then an hash function could be used such as this MurmurHash3 implementation:

``` javascript
function xmur3 (str) {
  let h = 1779033703 ^ str.length
  for (let i = 0; i < str.length; i++) {
    h = Math.imul(h ^ str.charCodeAt(i), 3432918353)
    h = h << 13 | h >>> 19
  }
  return function () {
    h = Math.imul(h ^ h >>> 16, 2246822507)
    h = Math.imul(h ^ h >>> 13, 3266489909)
    return (h ^= h >>> 16) >>> 0
  }
}
```

which could be used as such:

``` javascript
const seed = xmur3('' + Date.now() % 10000)
const rand = mulberry32(seed())
rand()
```

A good seed sometimes makes all the difference in the quality of the random number sequence being generated.

Now that we can generate repeatable sequences of random numbers, we can put them to use. I find the following two functions to be useful additions:

``` javascript
function randomFloat (min, max) {
  if (!max) {
    max = min
    min = 0
  }

  return rand() * (max - min) + min
}

function randomInt (min, max) {
  if (!max) {
    max = min
    min = 0
  }

  return Math.floor(randomFloat(min, max))
}
```

I can use `randomFloat` to randomly generate points on a canvas or RGB values for random colors.

``` javascript
// generate a random point on the canvas
const x = randomFloat(context.canvas.width)
const y = randomFloat(context.canvas.height)

// generate random rgb values
const r = randomFloat(256)
const g = randomFloat(256)
const b = randomFloat(256)
const color = `rgb(${r}, ${g}, ${b})`
```

I can use `randomInt` to choose random indexes of an array. In fact, a `pick` function could be written to take advantage of that so that I can get a random element from an array:

``` javascript
function pick (array) {
  if (array.length === 0) return undefined
  return array[randomInt(array.length)]
}
```

This just scratches the surface of what you can do with random numbers. Over time, you'll find other uses for randomness, such as randomly shuffling arrays, adding probability and chance to a program's execution, etc. There is plenty more to still learn.