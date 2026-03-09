# frozen_string_literal: true

FeatureFlagRolloutPbtConfig = {
  sut_factory: -> { FeatureFlagRolloutImpl.new(max_rollout: 100, rollout: 0) },
  initial_state: { rollout: 0, max_rollout: 100 },
  command_mappings: {
    enable: {
      method: :enable_globally,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed rollout state after enable to match model" unless observed_state == after_state
      end
    },
    disable: {
      method: :disable_globally,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed rollout state after disable to match model" unless observed_state == after_state
      end
    },
    rollout: {
      method: :set_rollout,
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed rollout state after set_rollout to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { rollout: sut.rollout, max_rollout: sut.max_rollout } }
  }
}
