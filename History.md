### 1.0.5 / 2017-12-12

* Require rgeo-activerecord 4.0.4
* Fix require for rgeo-activerecord 4.0.2
* Breaking change: remove #set_rgeo_factory_settings
* Breaking change: remove #rgeo_factory_for_column
* Breaking change: remove #has_spatial_constraints?
* Update gemspec to not allow update to ActiveRecord 4.2, as it does not work.
* Loosen rgeo-activerecord dependency
* Use ActiveSupport::TestCase for base test class
* Remove unused script_dir setting
* Remove internal rails4/ and shared/ directories
* Relax the ActiveRecord version requirement to support both 4.0.x and 4.1.x
  in a single gem.
* Backport: Only create extension "if not exists"
* Fix ActiveRecord 3.1 compatibility with activerecord-jdbc-adapter

### 1.0.0 / 2017-02-09

* Release

For earlier history, see the History file for the rgeo gem.