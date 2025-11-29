# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

Minitest::TestTask.create(:test_unit) do |t|
  t.test_globs = ["test/unit/**/*_test.rb", "test/test_yaic.rb"]
end

Minitest::TestTask.create(:test_integration) do |t|
  t.test_globs = ["test/integration/**/*_test.rb"]
end

require "standard/rake"

task default: %i[test standard]
