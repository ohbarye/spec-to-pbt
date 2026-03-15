# frozen_string_literal: true

if (pbt_repo_dir = ENV["PBT_REPO_DIR"])
  pbt_lib_dir = File.join(pbt_repo_dir, "lib")
  if Dir.exist?(pbt_lib_dir) && !$LOAD_PATH.include?(pbt_lib_dir)
    $LOAD_PATH.unshift(pbt_lib_dir)
  end
end

require "pbt"
