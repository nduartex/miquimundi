ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)
    fixtures :all

    # The test cache is a real MemoryStore (so rate-limit/dataset caching can be
    # exercised); clear it before each test to keep them isolated.
    setup { Rails.cache.clear }
  end
end
