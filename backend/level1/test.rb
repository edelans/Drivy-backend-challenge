#!/usr/bin/env ruby
require 'test/unit'
require 'fileutils'
require_relative 'main'


# simple test case for testing level completion
class TestLevel < Test::Unit::TestCase
  def test_identical_output_files
    FileUtils.identical?('output.json', 'computed_output.json')
  end
end
