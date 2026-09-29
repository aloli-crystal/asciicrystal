Root cause found, with a proposed fix (patch below, applies cleanly to 1.21.1).

**Versions.** Reproduced on 1.18.2, 1.19.1, 1.20.0 and 1.21.1 (Homebrew, LLVM 23), including the `Hash` variant and the stack-overflow variant.

## What happens

Tracing type changes in an instrumented 1.19.1 compiler on the minimal reproduction:

1. `check_return_type` sets `typed_def.freeze_type` to the looked-up restriction `{Int32, Gen(String)}`. Generic type arguments are virtualized in `TypeLookup#lookup(node : Generic)` (`type_vars << type.virtual_type`), and `GenericClassInstanceType#virtual_type` checks `generic_type.leaf?`, so as soon as `Gen` has *any* subclass the freeze type is really `Tuple(Int32, Gen(String)+)`. (`TupleInstanceType#to_s` prints it as `Tuple(Int32, Gen(String))`, which makes it look identical to the body type in messages.)
2. While the body is not typed yet, the recursive call `f(g)` gets its type from `ASTNode#type?`, which returns `@type || freeze_type`, i.e. the provisional `Tuple(Int32, Gen(String)+)`. The tuple indexer `tmp[1]` therefore types as `Gen(String)+`, and `g`, its meta vars and the `while` vars widen to `Gen(String)+`.
3. Once the body is typed, the def gets its real type `Tuple(Int32, Gen(String))`, a **distinct, narrower** type (it implements the freeze type, so no error). Observers recalculate: the call, the indexer, the assigned `Var` and some meta vars shrink back to `Gen(String)`, but other dependents (for instance the `Var g` read in `while g`) keep `Gen(String)+`.
4. Codegen then reads a `Var` typed `Gen(String)+` from a context var allocated as `Gen(String)`, and `downcast` is asked to go from `Gen(String)` to `Gen(String)+`: `BUG: trying to downcast Gen(String)+ <- Gen(String)`. Without the `if`, the types keep flipping between the two, hence the `Call#recalculate` ↔ `notify_observers` stack overflow.

So the underlying problem is that the provisional type a def hands out through `freeze_type` can be **wider** than its final type, and type propagation is not prepared for a type that shrinks afterwards. The spurious `Gen(String)+` (point 1) only makes it easy to hit: `class Sub < Gen(String)` fails the same way, with a legitimately virtual type.

## Proposed fix

Keep using the restriction as the provisional type (it is needed: without it, recursion through a block, e.g. `@kids.sum { |k| k.total }` in `def total : Int32`, no longer types), but remember that it was handed out, and in that case do not let the def's type shrink below it:

```diff
--- a/src/compiler/crystal/semantic/ast.cr
+++ b/src/compiler/crystal/semantic/ast.cr
@@ -144,6 +144,11 @@
     property next : Def?
     property special_vars : Set(String)?
     property freeze_type : Type?
+
+    # Set when `type?` handed out `freeze_type` because the body was not
+    # typed yet (a recursive call). The def's type must not shrink below
+    # that provisional type afterwards, see `restrict_type_to_freeze_type`.
+    property? freeze_type_exposed = false
     property block_nest = 0
     property? raises = false
     property? closure = false
--- a/src/compiler/crystal/semantic/bindings.cr
+++ b/src/compiler/crystal/semantic/bindings.cr
@@ -83,7 +83,12 @@
     end
 
     def type?
-      @type || freeze_type
+      if type = @type
+        type
+      elsif freeze_type = self.freeze_type
+        self.freeze_type_exposed = true if self.is_a?(Def)
+        freeze_type
+      end
     end
 
     def type(*, with_autocast = false)
@@ -307,6 +312,15 @@
     #
     # Special cases are listed inside the method body.
     def restrict_type_to_freeze_type(freeze_type, type)
+      # A def whose declared return type was already used as its provisional
+      # type (recursive call typed before the body) keeps that type: letting
+      # it shrink to the body's narrower type leaves dependent nodes with
+      # stale, wider types (codegen "BUG: trying to downcast" or endless
+      # recalculation).
+      if self.is_a?(Def) && self.freeze_type_exposed? && type != freeze_type && type.implements?(freeze_type)
+        return freeze_type
+      end
+
       if freeze_type.is_a?(ProcInstanceType)
         # We allow assigning Proc(*T, R) to Proc(*T, Nil)
         if freeze_type.return_type.nil_type? &&
```

Regression specs for `spec/compiler/codegen/def_spec.cr` (they use `&-` since codegen specs run without the prelude):

```crystal
  it "codegens recursive def whose tuple return restriction holds a virtual generic instance (#17507)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Gen(T)
      end

      class Sub < Gen(Int32)
      end

      def f(g : Gen(String), n : Int32) : {Int32, Gen(String)}
        while n > 0
          if 1
            _, g = f(g, n &- 1)
          end
          n &-= 1
        end
        {1, Gen(String).new}
      end

      f(Gen(String).new, 2)[0]
      CRYSTAL
  end

  it "types recursive def whose tuple return restriction holds a virtual generic instance, without if (#17507)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Gen(T)
      end

      class Sub < Gen(Int32)
      end

      def f(g : Gen(String), n : Int32) : {Int32, Gen(String)}
        while n > 0
          _, g = f(g, n &- 1)
          n &-= 1
        end
        {1, Gen(String).new}
      end

      f(Gen(String).new, 2)[0]
      CRYSTAL
  end
```

## What I checked (1.19.1 sources + patch, LLVM 22, macOS arm64)

- All reproductions from the issue compile and run: the `Gen` one, the `class Sub < Gen(String)` variant, the `Hash` one, the stack-overflow one, and the real-world case (the `asciicrystal` shard used together with a `Hash` subclass, which fails on every released version).
- `typeof` is unchanged for non-recursive defs with restrictions (`def foo : Int32 | String; 1; end` is still `Int32`, `def bar : A; B.new; end` still `B`), and for recursive ones (`def r(n) : A; n > 0 ? r(n - 1) : B.new; end` is `A` before and after). The only type that changes is the one of a recursive def whose body type is strictly narrower than the provisional restriction, i.e. exactly the crashing case.
- Recursion without a typed base case, mutual recursion and recursion through a block type as before.
- Compiler specs: `semantic/{abstract_def, def_overload, def, generic_class, named_tuple, no_return, previous_def, recursive_struct_check, restrictions_augmenter, restrictions, return, tuple, virtual_metaclass, virtual}_spec.cr`: 683 examples, 0 failures; `codegen/{def_default_value, def, generic_class, named_tuple, no_return, previous_def, return, tuple, virtual}_spec.cr`: 208 examples, 0 failures. The two new specs pass with the patch; without it, the spec process dies with "Stack overflow".
- **Not run:** the full compiler and stdlib spec suites.

Side notes, not needed for the fix:

- `GenericClassInstanceType#virtual_type` testing `generic_type.leaf?` means that a subclass of `Hash(String, Int32 | String | Nil)` virtualizes `Hash(String, String)` as well. Checking the instance's own subclasses would avoid needless virtual types, but on its own it would not fix this issue (`class Sub < Gen(String)` still crashes).
- `TupleInstanceType#to_s` hides the `+` of virtual element types, so two distinct types print identically, which made this hard to see.
