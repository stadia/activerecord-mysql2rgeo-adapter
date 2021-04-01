### 5.2.4 / 2021-03-28

* Support JRuby #332

### 5.2.2 / 2018-12-02

* Freeze strings


** Note: rgeo 2.0 is supported with version 5.1.0+
** The rgeo gem version requirement is specified by rgeo-activerecord


### 5.2.1 / 2018-03-05

* Fix type parsing for Z/M variants with no SRID #281, #282
* Test ActiveRecord 5.2 with pg gem version 1.0.0 #279

### 5.2.0 / 2017-12-24

* Support comments - #275

### 5.1.0 / 2017-12-02

* Require rgeo-activerecord 6.0, require rgeo 1.0. #272

### 5.0.3 / 2017-11-09

* Improve requires, fix warnings #268
* Improve readme #264
* Fix Travis #261
* Remove comment #260
* Fix regex for parsing spacial column types #259

### 5.0.2 / 2017-06-14

* Use PG::Connection instead of PGconn #257

### 5.0.1 / 2017-05-01

* Fix activerecord gem dependency - 69e8815

### 5.0.0 / 2017-05-01 *** YANKED

* Support ActiveRecord 5.1 - #246

### 4.1.2 / 2018-03-05

* Fix type parsing for Z/M variants with no SRID #283

### 4.1.1 / 2017-12-24

* Support comments - backport #275

### 4.1.0 / 2017-12-02

* Require rgeo-activerecord 6.0, require rgeo 1.0.

### 4.0.5 / 2017-11-09

* Backport fixes from master #270
* Fix circular require warning
* Improve requires
* Fix regex for parsing spacial column types #259

### 4.0.4 / 2017-06-14

* Use PG::Connection instead of PGconn #257

### 4.0.3 / 2017-04-30

* Fix st_point, st_polygon exports (affects schema.rb) #253, #226

### 4.0.2 / 2016-11-13

* Revert #237

### 4.0.1 / 2016-11-08 *** YANKED

* Auto-load tasks (#237)

### 4.0.0 / 2016-06-30

* Support ActiveRecord 5.0 (#213)
* Fix schema dump null issues in JRuby (#229)

### 3.1.5 / 2017-04-30

* Fix st_point, st_polygon exports (affects schema.rb) #252, #226

### 3.1.4 / 2016-02-07

* Ignore PostGIS views on schema dump - #208

### 3.1.3 / 2016-01-15

* Restrict ActiveRecord support to 4.2. See 649707cdf

### 3.1.2 / 2015-12-29

* Require rgeo-activerecord 4.0.4

### 3.1.1 / 2015-12-28

* Fix require for rgeo-activerecord 4.0.2
* Rubocop-related cleanup #203

### 3.1.0 / 2015-11-19

* Add JRuby support (#199)

### 3.0.0 / 2015-05-25

* Support & require ActiveRecord 4.2 (#145)
* Require rgeo-activerecord 4.0 (#180, 089d2dedd9b)
* Rename adapter module from PostGISAdapter to PostGIS (c2fa909bb)
* Breaking change: remove #set_rgeo_factory_settings
* Breaking change: remove #rgeo_factory_for_column
* Breaking change: remove #has_spatial_constraints?

### 2.2.1 / 2014-09-22

* Update gemspec to not allow update to ActiveRecord 4.2, as it does not work.

### 2.2.0 / 2014-08-11

* Add JRuby support
  (https://github.com/rgeo/activerecord-postgis-adapter/pull/102)

### 2.1.1 / 2014-06-17

* Correct behavior of non-geographic null: false columns
  (https://github.com/rgeo/activerecord-postgis-adapter/pull/127)
* Loosen rgeo-activerecord dependency

### 2.1.0 / 2014-06-11

* Add a separate SpatialColumnInfo class to query spatial column info
  (https://github.com/rgeo/activerecord-postgis-adapter/pull/125)
* Update column migration method to correctly set null: false
  (https://github.com/rgeo/activerecord-postgis-adapter/pull/121)

### 2.0.2 / 2014-06-06

* Fix add_index for referenced columns (regression)
  (https://github.com/rgeo/activerecord-postgis-adapter/issues/60)
* Remove unused no_constraints option handling from add_column
  (https://github.com/rgeo/activerecord-postgis-adapter/pull/117)
* Use ActiveSupport::TestCase for base test class
* Remove unused script_dir setting


### 2.0.1 / 2014-05-16

* Fix sql index dump for non-spatial columns
  (https://github.com/rgeo/activerecord-postgis-adapter/issues/92)


### 2.0.0 / 2014-05-15

* Bump Major version bump because the location of the railtie.rb file has
  moved and some methods were removed.
* Remove special handling for the "postgis" schema (see
  https://github.com/rgeo/activerecord-postgis-adapter/pull/114)
* Consolidate the railtie files
* Remove internal rails4/ and shared/ directories


### 1.1.0 / 2014-05-07

* Relax the ActiveRecord version requirement to support both 4.0.x and 4.1.x
  in a single gem.
* The 0.7.x versions and 0.7-stable branch are now obsolete.