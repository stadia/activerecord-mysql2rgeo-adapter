# frozen_string_literal: true

exclude "test_legacy_change_column_with_null_executes_update", TRIAGE_MSG
exclude "test_disable_extension_on_7_0", TRIAGE_MSG
exclude "test_legacy_add_foreign_key_with_deferrable_true", TRIAGE_MSG
exclude "test_change_column_on_7_0", TRIAGE_MSG
# Flaky on MySQL: foreign_keys has no ORDER BY, so which FK to testings the 8.0-compat remove_foreign_key drops varies.
exclude "test_remove_foreign_key_on_8_0", "Order-dependent on MySQL foreign_keys result"
