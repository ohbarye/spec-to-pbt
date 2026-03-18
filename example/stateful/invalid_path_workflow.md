# Invalid-Path Workflow

This note shows the two main invalid-path recipes that the current scaffold supports well through config-only edits.

## Recipe 1: Out-Of-Range Scalar Arguments

Use this when the guard is shaped like:

- `amount <= state[:captured]`
- `amount <= state[:authorized_amount]`

Start with:

```ruby
command_mappings: {
  refund: {
    method: :refund,
    arguments_override: ->(state) { Pbt.integer(min: state[:captured] + 1, max: state[:captured] + 1) },
    guard_failure_policy: :raise
  }
},
verify_context: {
  state_reader: ->(sut) { { authorized: sut.authorized, captured: sut.captured, refunded: sut.refunded } }
}
```

Why this works:

- `arguments_override` forces a one-step-past-the-guard value
- `guard_failure_policy: :raise` lets the scaffold execute the invalid call
- `state_reader` makes silent invalid mutations visible when the SUT fails to reject

Representative domains:

- `partial_refund_remaining_capturable`
- `payment_status_amounts`

## Recipe 2: No-Arg Guard Failures

Use this when the command has no meaningful argument and the guard is state-only:

- `checked_out > 0`
- `status == 1 && retry_budget > 0`

Start with:

```ruby
command_mappings: {
  checkin: {
    method: :checkin,
    guard_failure_policy: :raise
  }
},
verify_context: {
  state_reader: ->(sut) { { available: sut.available, checked_out: sut.checked_out, capacity: sut.capacity } }
}
```

Why this works:

- `guard_failure_policy: :raise` bypasses the default valid-only applicability filter
- the good implementation raises
- a mutant that silently mutates state is caught by observed-state verification

Representative domains:

- `connection_pool`
- `job_status_event_counters`

## Rule Of Thumb

1. wire `verify_context.state_reader` first
2. use `arguments_override` only when the invalid path depends on an out-of-range argument
3. otherwise start with `guard_failure_policy: :raise`
4. reach for `verify_override` only when the invalid-path contract is domain-specific
