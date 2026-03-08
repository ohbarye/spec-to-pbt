# frozen_string_literal: true

pbt_repo_dir = ENV.fetch("PBT_REPO_DIR", File.expand_path("../../../pbt", __dir__))
pbt_lib_dir = File.join(pbt_repo_dir, "lib")

if Dir.exist?(pbt_lib_dir) && !$LOAD_PATH.include?(pbt_lib_dir)
  $LOAD_PATH.unshift(pbt_lib_dir)
end

require "pbt"
