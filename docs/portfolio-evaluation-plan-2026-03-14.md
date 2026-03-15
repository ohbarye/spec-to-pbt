# Portfolio Evaluation Plan

## Goal

Produce a repeatable case-study package that supports this claim:

- `spec-to-pbt` is a practical scaffold generator for formal-spec-to-PBT workflows
- generated stateful scaffolds can reach green through config/impl-only edits
- the resulting tests are useful because they detect injected defects across recurring pattern families

This phase is explicitly not about:

- parser breadth
- new frontend work
- speculative new domain families

## Portfolio

Use this fixed 4-domain portfolio.

### Financial

- `partial_refund_remaining_capturable`
- `ledger_projection`

### Software-general

- `job_status_event_counters`
- `connection_pool`

## Fixed Workflow Per Domain

For every domain:

1. generate with:
   - `bin/spec_to_pbt INPUT.als --stateful --with-config -o generated`
2. edit only:
   - `*_pbt_config.rb`
   - `*_impl.rb`
3. do not edit:
   - `*_pbt.rb`
4. run the scaffold to green
5. run 3 deterministic mutants
6. record practicality, friction, and mutant outcomes

Use a `pbt` release that provides `Pbt.stateful` (`pbt >= 0.5.1`) before running generated scaffolds.

## Metrics

Record these exact metrics per domain:

- `pbt_scaffold_edit_required`
  - `yes` / `no`
- `config_only_green`
  - `yes` / `no`
- `files_user_edited`
  - `config`
  - `impl`
  - `scaffold`
- `friction_categories`
- `mutants_detected / mutants_total`

Interpretation:

- practicality:
  - config/impl-only path to green
- usefulness:
  - mutant detection
- viability:
  - end-to-end success across all 4 domains

## Mutant Protocol

Use exactly 3 deterministic mutants per domain.

### Partial refund / remaining capturable

- update bug:
  - refund decrements the wrong field
- guard bug:
  - refund no longer rejects over-refund attempts
- preservation bug:
  - refund breaks conservation between `captured` and `refunded`

### Ledger projection

- projection bug:
  - append event but do not update balance
- update bug:
  - debit updates balance in the wrong direction
- append bug:
  - credit appends the wrong event value

### Job status event counters

- projection bug:
  - retry increments count but not event log
- update bug:
  - retry ignores retry-budget consumption
- lifecycle bug:
  - deactivate leaves status unchanged

### Connection pool

- update bug:
  - checkout mutates the wrong counter
- guard bug:
  - checkin is allowed when nothing is checked out
- preservation bug:
  - checkout breaks the availability/capacity relation

## Acceptance Criteria

This evaluation milestone is successful if:

1. all 4 domains reach green with config/impl-only edits
2. no domain requires normal editing of generated `*_pbt.rb`
3. friction is classified per domain
4. each domain has 3 executed mutants
5. the final results document supports a clear viability + usefulness claim
