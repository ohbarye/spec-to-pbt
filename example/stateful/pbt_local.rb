# frozen_string_literal: true

if ENV["PBT_REPO_DIR"]
  pbt_lib_dir = File.join(ENV["PBT_REPO_DIR"], "lib")

  unless Dir.exist?(pbt_lib_dir)
    raise LoadError, "PBT_REPO_DIR does not contain a lib directory: #{pbt_lib_dir}"
  end

  $LOAD_PATH.unshift(pbt_lib_dir) unless $LOAD_PATH.include?(pbt_lib_dir)
end

require "pbt"

unless Pbt.respond_to?(:stateful)
  version = Gem.loaded_specs["pbt"]&.version
  raise LoadError, "Loaded pbt#{version ? " #{version}" : ""} does not provide Pbt.stateful. Run `bundle update pbt` or set PBT_REPO_DIR to a newer checkout."
end
