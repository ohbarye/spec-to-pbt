# frozen_string_literal: true

AuthorizationExpiryVoidPbtConfig = {
  sut_factory: -> { AuthorizationExpiryVoidImpl.new(available: 20, held: 0) },
  initial_state: { available: 20, held: 0 },
  command_mappings: {
    authorize: {
      method: :authorize,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed authorization state after authorize to match model" unless observed_state == after_state
      end
    },
    void: {
      method: :void_authorization,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed authorization state after void to match model" unless observed_state == after_state
      end
    },
    expire: {
      method: :expire_authorization,
      model_arg_adapter: ->(args) { args.abs + 1 },
      verify_override: ->(after_state:, observed_state:, **) do
        raise "Expected observed authorization state after expiry to match model" unless observed_state == after_state
      end
    }
  },
  verify_context: {
    state_reader: ->(sut) { { available: sut.available, held: sut.held } }
  }
}
