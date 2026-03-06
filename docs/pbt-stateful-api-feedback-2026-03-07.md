# pbt Stateful API Feedback (2026-03-07)

## Summary

`spec-to-pbt` can now generate runnable stateful scaffolds with:

- config-driven SUT wiring
- `verify_override`
- `state_reader`
- richer structured model state for collection + companion scalar fields
- amount-aware scalar model updates via `model_arg_adapter`

The remaining practical bottleneck is the current command protocol shape in `pbt`.

Today a generated command effectively assumes:

- `arguments`
- `applicable?(state)`
- `next_state(state, args)`
- `run!(sut, args)`
- `verify!(...)`

This works well when applicability depends only on `state`, or when args are constant-shape.
It becomes awkward when args and applicability are coupled.

Two concrete cases from `spec-to-pbt`:

1. `BoundedQueue#enqueue(value)` with `capacity`
- whether `enqueue` is applicable depends on queue length relative to capacity
- this is still manageable by richer model state

2. `BankAccount#withdraw(amount)`
- whether `withdraw(amount)` is applicable depends on both current balance and chosen `amount`
- `applicable?(state)` alone is not expressive enough

## Problem

For commands like `withdraw(amount)` there are 3 bad options under the current protocol:

1. generate args without looking at state
- this produces lots of invalid commands

2. encode validity only in `applicable?(state)`
- impossible when validity depends on `args`

3. push everything into ad hoc config or overrides
- workable, but defeats much of the generator's value

The missing capability is one of:

- state-dependent argument generation
- arg-aware applicability

Ideally both.

## Recommended API Direction

### Option A: `arguments(state)`

Allow commands to generate args from current model state.

Example shape:

```ruby
class WithdrawCommand
  def arguments(state)
    max_amount = state[:balance]
    Pbt.integer(min: 1, max: max_amount)
  end
end
```

Pros:

- natural fit for generators
- avoids generating obviously invalid args
- keeps invalid-command noise low

Cons:

- still may need applicability for additional domain rules

### Option B: `applicable?(state, args)`

Allow applicability to depend on both state and chosen args.

Example shape:

```ruby
class WithdrawCommand
  def arguments
    Pbt.integer(min: 1, max: 100)
  end

  def applicable?(state, args)
    args <= state[:balance]
  end
end
```

Pros:

- simple extension to the current protocol
- explicit contract

Cons:

- may still generate a lot of rejected commands if args are unconstrained

### Recommended Outcome

Support both, with this precedence:

1. if command responds to `arguments(state)`, call it
2. otherwise fall back to current `arguments`
3. if command responds to `applicable?(state, args)`, use it
4. otherwise fall back to current `applicable?(state)`

That gives backwards compatibility and a clean migration path.

## Concrete Use Cases

### Bounded Queue

Desired generated command:

```ruby
def applicable?(state, _args)
  state[:elements].length < state[:capacity]
end
```

or:

```ruby
def arguments(state)
  return Pbt.nil if state[:elements].length >= state[:capacity]

  Pbt.integer
end
```

### Bank Account

Desired generated command:

```ruby
def arguments(state)
  max_amount = state[:balance]
  Pbt.integer(min: 1, max: max_amount)
end
```

or:

```ruby
def applicable?(state, amount)
  amount <= state[:balance]
end
```

This is the difference between:

- “high-quality scaffold with manual workaround”

and

- “practical generated test that directly matches the domain”

## Suggested Prompt For Another AI

Use this as the implementation prompt for the `pbt` repository.

```text
Implement a backward-compatible extension to the stateful command protocol in the pbt gem.

Current command protocol effectively assumes:
- name
- arguments
- applicable?(state)
- next_state(state, args)
- run!(sut, args)
- verify!(...)

This is insufficient for commands whose validity depends on both state and args, such as:
- withdraw(amount), where amount must be <= balance
- bounded enqueue(value), where enqueue is only valid when size < capacity

Please extend the stateful runner with backward compatibility:

1. Support state-dependent argument generation
- If a command responds to `arguments(state)`, call that form
- Otherwise fall back to current `arguments`

2. Support arg-aware applicability
- If a command responds to `applicable?(state, args)`, call that form
- Otherwise fall back to current `applicable?(state)`

3. Preserve current behavior for existing commands that implement only the old protocol

4. Add tests for both new capabilities
- legacy command with `arguments` + `applicable?(state)` still passes unchanged
- command with `arguments(state)` works
- command with `applicable?(state, args)` works
- command with both works

5. Update failure messages only if needed to keep debugging clear

Do not redesign the entire stateful API.
Keep the change small, additive, and backward-compatible.
```

## Why This Matters For `spec-to-pbt`

If this lands in `pbt`, `spec-to-pbt` can generate much better practical tests for:

- financial operations with amount constraints
- bounded data structures
- commands with resource limits or domain caps
- workflows whose valid transitions depend on selected inputs

Without it, `spec-to-pbt` remains viable, but has to rely more heavily on:

- `applicable_override`
- config-level argument normalization
- hand-edited scaffolds

Those are acceptable escape hatches, but not the ideal end state.
