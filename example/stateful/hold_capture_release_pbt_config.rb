# frozen_string_literal: true

HoldCaptureReleasePbtConfig = {
  sut_factory: -> { HoldCaptureReleaseImpl.new(available: 10, held: 0) },
  initial_state: { available: 10, held: 0 },
  command_mappings: {
    hold: {
      method: :hold,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed reservation state after hold to match model" unless observed_state == after_state
      end
    },
    capture: {
      method: :capture,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed reservation state after capture to match model" unless observed_state == after_state
      end
    },
    release: {
      method: :release,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed reservation state after release to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { available: sut.available, held: sut.held } }
  }
}
