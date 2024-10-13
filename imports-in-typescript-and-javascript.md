# Imports in Typescript and Javascript

My first real experience with writing imports and exports for Javascript in Node was via Typescript where with the benefit of the compiler I was able to write the following:

``` javascript
// module.ts
export function add(x: number, y: number): number {
    return x + y
}

// main.ts
import { add } from './module';

add(1, 2)
```

Because of this I didn't really need to understand how this code was compiled into the  Javascript that supported the CommonJS way of exporting and importing code. So, to start at the beginning, how did one export and import code using CommonJS in Node?

``` javascript
// module.js
exports.add = function(x, y) {
    return x + y
}

// main.js
const { add } = require('./module.js');

add(1, 2)
```

Well, actually, that is just one way. The following are also possible:

``` javascript
// module.js
exports.add = function(x, y) {
    return x + y
}

// main.js
const module = require('./module.js');

module.add(1, 2)
```

and

``` javascript
// module.js
module.exports.add = function(x, y) {
    return x + y
}

// main.js
const { add } = require('./module.js');

add(1, 2)
```

and

``` javascript
// module.js
module.exports = {
    add: function(x, y) {
        return x + y
    }
}

// main.js
const { add } = require('./module.js');

add(1, 2)
```

Basically, Typescript gives us an ability to do imports and exports using the newer ESModules spec and it would compile that code into CommmonJS export/requires when targeting Node. For the most part, it is pretty straightforward to understand how the Typescript code would look in the equivalent CommonJS. And it is easy to reason about how one would interop with the other.

``` javascript
// module.js
exports.add = function(x, y) {
    return x + y
}

// main.ts
import { add } from './module.js';

add(1, 2)
```

The problem is that the following is valid CommonJS code:

``` javascript
const add = function (x, y) {
    return x + y;
};

module.exports = add
```

And if you export your code in this way, then you can't import this in the way you would expect in Typescript:

``` javascript
import add from './module.js';

add(1, 2);
```

and

``` javascript
import { add } from './module.js';

add(1, 2);
```

are not valid. Instead you would have to import this code like so:

```javascript
import * as add from './module.js';

add(1, 2);
```

Unfortunately, this workaround is not valid under the ESModule spec, becuase `add` could only be an object here. It could not be a callable.

To combat this problem, Typescript introduced the `esModuleInterop` flag, which allows us to import CommonJS modules in compliance with the ESModules spec. So, with this flag set to true, you can import the code like so:

``` javascript
import add from './module.js';

add(1, 2);
```

And it will work. The Typescript code will be compiled to this Javascript code:

``` javascript
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const module_js_1 = __importDefault(require("./module.js"));
module_js_1.default(1, 2);
```

All of this makes the above code that defines the `add` equivalent to this Typescript/ESModule code that defines a `mul` function:

``` javascript
export default function mul(x: number, y: number): number {
    return x * y;
}
```

Both of these can now be imported in the same way:

``` javascript
import add from './module.js';
import mul from './module2';

add(1, 2);
mul(3, 4)
```

Like anything in the world of Javascript there are many ways to accomplish something. All of the following examples are valid.

``` javascript
// module.js
exports.sub = function(x, y) {
    return x - y;
}

exports.div = function(x, y) {
    return x / y;
}

// main.ts
import math, { sub } from './module.js';

sub(6, 5)
math.div(9, 3)
```

``` javascript
// module.js
module.exports = {
    pow: function(x, y) {
        return Math.pow(x, y)
    },
    imul: function(x, y) {
        return Math.imul(x, y)
    }
}

// main.ts
import { imul, pow } from './module4.js';

// or

import test from './module4.js';

pow(4, 2)
imul(5, 2)

// or

test.pow(4, 2)
test.imul(5, 1)
```

It is now recommended to use `esModuleInterop` to with Typescript and doing so should make it easier to write code that adheres to the ESModules spec. This is a good thing, because in my opinion the best way to write Typescript is as nothing more than Javascript with types added.


### References

- [Modules: CommonJS modules | Node.js Documentation](https://nodejs.org/api/modules.html)
- [Modules: ECMAScript modules | Node.js Documentation](https://nodejs.org/api/esm.html)
- [export - Web technology for developers | MDN](https://developer.mozilla.org/en-US/docs/web/javascript/reference/statements/export)
- [import - JavaScript | MDN](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/import)
- [TypeScript: TSConfig Reference - esModuleInterop](https://www.typescriptlang.org/tsconfig#esModuleInterop)