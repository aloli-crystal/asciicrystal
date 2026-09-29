# Codegen BUG: "trying to downcast Gen(String)+ <- Gen(String)" when a generic instance is reassigned from a recursive call returning a tuple

<!--
Draft of an issue for https://github.com/crystal-lang/crystal/issues — not yet
filed. Found while using the `asciicrystal` shard from a Marten application
(Marten defines `class MatchParameters < Hash(String, Parameter::Types)`).
Worked around in asciicrystal 2.0.26.23 (src/asciicrystal/parser.cr,
`Parser#next_section`).
-->

## Bug report

The compiler crashes during codegen as soon as the program contains **any
subclass of a generic class instance**, combined with a method that:

1. declares a tuple return type containing another instance of that generic
   (`: {Int32, Gen(String)}`),
2. reassigns its restricted parameter from a recursive call inside a `while`
   loop, nested in an `if`,
3. returns a freshly built instance in the tuple.

### Minimal reproduction (no shard, no stdlib generic)

```crystal
class Gen(T)
end

class Sub < Gen(Int32)
end

def f(g : Gen(String)) : {Int32, Gen(String)}
  while g
    if 1
      _, g = f(g)
    end
  end
  {0, Gen(String).new}
end

f(Gen(String).new)
```

```
$ crystal build repro.cr
BUG: trying to downcast Gen(String)+ (Crystal::VirtualType) <- Gen(String) (Crystal::GenericClassInstanceType) (Exception)
  from .../crystal in 'raise<Exception>:NoReturn'
  from .../crystal in 'raise<String>:NoReturn'
  from .../crystal in 'Crystal::CodeGenVisitor#downcast_distinct<LLVM::Value, Crystal::Type+, Crystal::Type+>:NoReturn'
  from .../crystal in 'Crystal::CodeGenVisitor#downcast:extern<LLVM::Value, Crystal::Type+, Crystal::Type+, Bool, Bool>:LLVM::Value'
  from .../crystal in 'Crystal::CodeGenVisitor#visit<Crystal::Var+>:Bool'
  from .../crystal in 'Crystal::ASTNode+@Crystal::ASTNode#accept<Crystal::CodeGenVisitor>:Nil'
  from .../crystal in 'Crystal::CodeGenVisitor#visit<Crystal::Call>:Bool'
  ...
  from .../crystal in 'Crystal::CodeGenVisitor#visit<Crystal::While>:Bool'
  ...
Error: you've found a bug in the Crystal compiler. Please open an issue, including source code that will allow us to reproduce the bug: https://github.com/crystal-lang/crystal/issues
```

Same result with `--no-debug` and `--release`. `crystal build --no-codegen`
succeeds, so semantic analysis accepts the program.

The same happens with standard library generics, which is how it was found:
any program that defines a `Hash` subclass (e.g. Marten's
`class MatchParameters < Hash(String, Parameter::Types)`) cannot compile code
shaped like the above for `Hash(String, String)`:

```crystal
class Foo < Hash(Int32, Int32)
end

def f(h : Hash(String, String)) : Tuple(Int32, Hash(String, String))
  while h.empty?
    if 1
      x, h = f(h)
    end
  end
  {0, h.dup}
end

f({} of String => String)
# BUG: trying to downcast Hash(String, String)+ (Crystal::VirtualType) <- Hash(String, String) (Crystal::GenericClassInstanceType)
```

(`Array` behaves the same: `class Foo < Array(Int32)` + `Array(String)`.)

### What matters

| Variant | Result |
|---|---|
| As above | BUG (codegen) |
| Without `class Sub < Gen(Int32)` | compiles |
| Subclass of the *same* instance (`class Sub < Gen(String)`) | BUG |
| No return type restriction on `f` | compiles |
| Return type `: Gen(String)` instead of a tuple (`g = f(g)`) | compiles |
| `g = f(g)[1]` instead of `_, g = f(g)` | BUG |
| Return `{0, g}` (the parameter itself) instead of a new instance | compiles |
| Return `{0, Gen(String).new.as(Gen(String))}` | compiles (workaround) |
| Copy the parameter to a local first (`h = g`, then reassign `h`) | BUG |
| Without the `if 1` around the recursive call | the compiler itself dies with **"Stack overflow (e.g., infinite or very deep recursion)"** during semantic analysis (`Call#recalculate` ↔ `ASTNode#notify_observers` loop) |

It looks like the tuple return restriction is resolved to
`Tuple(Int32, Gen(String)+)` once `Gen` has a subclass, so the reassigned
variable `g` gets the virtual type `Gen(String)+`, while some path still
stores a non-virtual `Gen(String)` for it, and codegen then tries to
"downcast" in the wrong direction. The stack-overflow variant is probably the
same type-propagation issue failing to reach a fixed point.

### Workaround

Cast the freshly built value explicitly in the returned tuple:

```crystal
{0, Gen(String).new.as(Gen(String))}
```

or drop the return type restriction.

### Environment

```
Crystal 1.19.1 [a3178c32b] (2026-01-20)

LLVM: 15.0.7
Default target: aarch64-apple-macosx11.0
```

macOS (Apple Silicon).
