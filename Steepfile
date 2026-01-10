# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig/generated"

  check "lib"

  # Standard library dependencies
  library "erb"
  library "json"

  configure_code_diagnostics do |config|
    config[D::Ruby::UndeclaredMethodDefinition] = :hint
  end
end
