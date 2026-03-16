# frozen_string_literal: true

module StatefulPbtRuntimeHelper
  def explicit_pbt_repo_dir
    value = ENV["PBT_REPO_DIR"]
    return nil if value.nil? || value.empty?

    value
  end

  def stateful_pbt_env
    env = { "ALLOY_TO_PBT_RUN_STATEFUL_SCAFFOLD" => "1" }
    return env unless explicit_pbt_repo_dir

    pbt_lib_dir = File.join(explicit_pbt_repo_dir, "lib")
    env["PBT_REPO_DIR"] = explicit_pbt_repo_dir
    env["RUBYOPT"] = [ENV["RUBYOPT"], "-I#{pbt_lib_dir}"].compact.join(" ") if Dir.exist?(pbt_lib_dir)
    env
  end
end

RSpec.configure do |config|
  config.include StatefulPbtRuntimeHelper
end
