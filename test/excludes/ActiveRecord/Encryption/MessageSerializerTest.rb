# frozen_string_literal: true

# json >= 3.0 no longer creates additions in JSON.load, so the test's own ArgumentError expectation fails.
# Fixed on rails/rails main (JSON::VERSION check) but not in 7-2-stable; drop this once the test is backported.
exclude "test_won't_load_classes_from_JSON", "Asserts json < 3.0 JSON.load behavior; unrelated to the adapter"
