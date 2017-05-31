# Mysql2Rgeo ActiveRecord Adapter

[![Gem Version](https://badge.fury.io/rb/activerecord-mysql2rgeo-adapter.svg)](https://badge.fury.io/rb/activerecord-mysql2rgeo-adapter)
[![Build Status](https://travis-ci.org/stadia/activerecord-mysql2rgeo-adapter.svg?branch=master)](https://travis-ci.org/stadia/activerecord-mysql2rgeo-adapter)
[![Code Climate](https://codeclimate.com/github/stadia/activerecord-mysql2rgeo-adapter.png)](https://codeclimate.com/github/stadia/activerecord-mysql2rgeo-adapter)

The activerecord-mysql2rgeo-adapter provides access to features
of the MySQL geospatial database from ActiveRecord. It uses the
[RGeo](http://github.com/rgeo/rgeo) library to represent spatial data in Ruby.

## Overview

The adapter provides three basic capabilities:

First, it provides *spatial migrations*. It extends the ActiveRecord migration
syntax to support creating spatially-typed columns and spatial indexes. You
can control the various PostGIS-provided attributes such as srid, dimension,
and geographic vs geometric math.

Second, it recognizes spatial types and casts them properly to RGeo geometry
objects. The adapter can configure these objects automatically based on the
srid and dimension in the database table, or you can tell it to convert the
data to a different form. You can also set attribute data using WKT format.

Third, it lets you include simple spatial data in queries. WKT format data and
RGeo objects can be embedded in where clauses.

## Install

The adapter requires Mysql 5.6+.

Gemfile:

```ruby
gem 'activerecord-mysql2rgeo-adapter'
```

Gemfile for JRuby:

```ruby
gem 'activerecord-mysql2rgeo-adapter'
gem 'jdbc-mysql', platform: :jruby
gem 'activerecord-jdbc-adapter', platform: :jruby
gem 'ffi-geos'
```

_JRuby support for Rails 4.0 and 4.1 was added in version 2.2.0_

#### Version 5.x supports ActiveRecord 5.1+

Requirements:

```
ActiveRecord 5.1+
Ruby 2.2.2+ (no JRuby support yet)
PostGIS 2.0+
```

#### Version 4.x supports ActiveRecord 5.0+

Requirements:

```
ActiveRecord 5.0+
Ruby 2.2.2+, JRuby
```

#### Version 3.x supports ActiveRecord 4.2

Requirements:

```
ActiveRecord 4.2
Ruby 1.9.3+, JRuby
```

##### database.yml

You must modify your `config/database.yml` file to use the mysql2rgeo
adapter. At minimum, you will need to change the `adapter` field from
`mysql2` to `mysql2rgeo`. Recommended configuration:

```
development:
  username:           your_username
  adapter:            mysql2rgeo
  host:               localhost
```

Here are some other options that are supported:

```
development:
  adapter: mysql2rgeo
  encoding: unicode
  pool: 5
  database: my_app_development    # your database name
  username: my_app_user           # the username your app will use to connect
  password: my_app_password       # the user's password
```

##### `rgeo` dependency

This adapter uses the `rgeo` gem, which has additional dependencies.
Please see the README documentation for `rgeo` for more information: https://github.com/rgeo/rgeo

## Creating a Spatial Rails App

This section covers starting a new Rails application from scratch. If you need
to add geospatial capabilities to an existing Rails application (i.e. you need
to convert a non-spatial database to a spatial database), see the section on
"Upgrading a Database With Spatial Features" below.

To create a new Rails application using `activerecord-mysql2rgeo-adapter`, start by
using the mysql2 adapter.

```sh
rails new my_app --database=mysql
```

Add the adapter gem to the Gemfile:

```ruby
gem 'activerecord-mysql2rgeo-adapter'
```

Once you have set up your database config, run:

```sh
rake db:create
```

to create your development database. The adapter will add the PostGIS extension to your database.

Once you have installed the adapter, edit your `config/database.yml` as described above.

## Upgrading an Existing Database

If you have an existing Rails app that uses Postgres,
and you want to add geospatial features, follow these steps.

First, add the `activerecord-mysql2rgeo-adapter` gem to the Gemfile, and update
your bundle by running `bundle install`.

Next, modify your `config/database.yml` file to invoke the mysql2rgeo adapter, as
described above.

### Creating Spatial Tables

To store spatial data, you must create a column with a spatial type. PostGIS
provides a variety of spatial types, including point, linestring, polygon, and
different kinds of collections. These types are defined in a standard produced
by the Open Geospatial Consortium. You can specify options indicating the coordinate
system and number of coordinates for the values you are storing.

The activerecord-mysql2rgeo-adapter extends ActiveRecord's migration syntax to
support these spatial types. The following example creates five spatial
columns in a table:

```ruby
create_table :my_spatial_table do |t|
  t.column :shape1, :geometry
  t.geometry :shape2
  t.line_string :path
  t.point :lonlat
  t.point :lonlatheight
end
```

The first column, "shape1", is created with type "geometry". This is a general
"base class" for spatial types; the column declares that it can contain values
of *any* spatial type.

The second column, "shape2", uses a shorthand syntax for the same type as the shape1 column.
You can create a column either by invoking `column` or invoking the name of the type directly.

The third column, "path", has a specific geometric type, `line_string`. It
also specifies an SRID (spatial reference ID) that indicates which coordinate
system it expects the data to be in. The column now has a "constraint" on it;
it will accept only LineString data, and only data whose SRID is 3785.

The fourth column, "lonlat", has the `point` type, and accepts only Point
data. Furthermore, it declares the column as "geographic", which means it
accepts longitude/latitude data, and performs calculations such as distances
using a spheroidal domain.

The fifth column, "lonlatheight", is a geographic (longitude/latitude) point
that also includes a third "z" coordinate that can be used to store height
information.

The following are the data types understood by PostGIS and exposed by
activerecord-mysql2rgeo-adapter:

* `:geometry` -- Any geometric type
* `:point` -- Point data
* `:line_string` -- LineString data
* `:polygon` -- Polygon data
* `:geometry_collection` -- Any collection type
* `:multi_point` -- A collection of Points
* `:multi_line_string` -- A collection of LineStrings
* `:multi_polygon` -- A collection of Polygons

To create a spatial index, add `type: :spatial` to your index:

```ruby
add_index :my_table, :lonlat, type: :spatial

# or

change_table :my_table do |t|
  t.index :lonlat, type: :spatial
end
```

### Point and Polygon Types with ActiveRecord 4.2+

Prior to version 3, the `point` and `polygon` types were supported.

### Configuring ActiveRecord

ActiveRecord's usefulness stems from the way it automatically configures
classes based on the database structure and schema. If a column in the
database has an integer type, ActiveRecord automatically casts the data to a
Ruby Integer. In the same way, the activerecord-mysql2rgeo-adapter automatically
casts spatial data to a corresponding RGeo data type.

RGeo offers more flexibility in its type system than can be
interpreted solely from analyzing the database column. For example, you can
configure RGeo objects to exhibit certain behaviors related to their
serialization, validation, coordinate system, or computation. These settings
are embodied in the RGeo factory associated with the object.

You can configure the adapter to use a particular factory (i.e. a
particular combination of settings) for data associated with each type in
the database.

Here's an example using a Geos default factory:

```ruby
RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # By default, use the GEOS implementation for spatial columns.
  config.default = RGeo::Geos.factory_generator

  # But use a geographic implementation for point columns.
  config.register(RGeo::Geographic.spherical_factory(srid: 4326), geo_type: "point")
end
```

The default spatial factory for geographic columns is `RGeo::Geographic.spherical_factory`.
The default spatial factory for cartesian columns is `RGeo::Cartesian.preferred_factory`.
You do not need to configure the `SpatialFactoryStore` if these defaults are ok.

For more explanation of `SpatialFactoryStore`, see [the rgeo-activerecord README] (https://github.com/rgeo/rgeo-activerecord#spatial-factories-for-columns)

## Working With Spatial Data

Of course, you're using this adapter because you want to work with geospatial
data in your ActiveRecord models. Once you've installed the adapter, set up
your database, and run your migrations, you can interact directly with spatial
data in your models as RGeo objects.

RGeo is a Ruby implementation of the industry standard OGC Simple Features
specification. It's a set of data types that can represent a variety of
geospatial objects such as points, lines, polygons, and collections. It also
provides the standard set of spatial analysis operations such as computing
intersections or bounding boxes, calculating length or area, and so forth. We
recommend browsing the RGeo documentation for a clearer understanding of its
capabilities. For now, just note that the data values you will be working with
are all RGeo geometry objects.

### Reading and Writing Spatial Columns

When you access a spatial attribute on your ActiveRecord model, it is given to
you as an RGeo geometry object (or nil, for attributes that allow null
values). You can then call the RGeo api on the object. For example, consider
the MySpatialTable class we worked with above:

    record = MySpatialTable.find(1)
    p = record.lonlat                  # Returns an RGeo::Feature::Point
    puts p.x                           # displays the x coordinate
    puts p.geometry_type.type_name     # displays "Point"

The RGeo factory for the value is determined by how you configured the
ActiveRecord class, as described above. In this case, we explicitly set a
spherical factory for the `:lonlat` column:

    factory = p.factory                # returns a spherical factory

You can set a spatial attribute by providing an RGeo geometry object, or by
providing the WKT string representation of the geometry. If a string is
provided, the activerecord-mysql2rgeo-adapter will attempt to parse it as WKT and
set the value accordingly.

    record.lonlat = 'POINT(-122 47)'  # sets the value to the given point

If the WKT parsing fails, the value currently will be silently set to nil. In
the future, however, this will raise an exception.

    record.lonlat = 'POINT(x)'         # sets the value to nil

If you set the value to an RGeo object, the factory needs to match the factory
for the attribute. If the factories do not match, activerecord-mysql2rgeo-adapter
will attempt to cast the value to the correct factory.

    p2 = factory.point(-122, 47)       # p2 is a point in a spherical factory
    record.lonlat = p2                 # sets the value to the given point
    record.shape1 = p2                 # shape1 uses a flat geos factory, so it
                                       # will cast p2 into that coordinate system
                                       # before setting the value
    record.save

If, however, you attempt to set the value to the wrong type-- for example,
setting a linestring attribute to a point value, you will get an exception
from Postgres when you attempt to save the record.

    record.path = p2      # This will appear to work, but...
    record.save           # This will raise an exception from the database

### Spatial Queries

You can create simple queries based on representational equality in the same
way you would on a scalar column:

    record2 = MySpatialTable.where(:lonlat => factory.point(-122, 47)).first

You can also use WKT:

    record3 = MySpatialTable.where(:lonlat => 'POINT(-122 47)').first

Note that these queries use representational equality, meaning they return
records where the lonlat value matches the given value exactly. A 0.00001
degree difference would not match, nor would a different representation of the
same geometry (like a multipoint with a single element). Equality queries
aren't generally all that useful in real world applications. Typically, if you
want to perform a spatial query, you'll look for, say, all the points within a
given area. For those queries, you'll need to use the standard spatial SQL
functions provided by PostGIS.

## Development and Support

Contributions are welcome. See CONTRIBUTING.md for instructions.

Report issues at http://github.com/stadia/activerecord-mysql2rgeo-adapter/issues

Support is also available on the rgeo-users google group at http://groups.google.com/group/rgeo-users

## License

Copyright Yongdae Hwang

https://github.com/stadia/activerecord-mysql2rgeo-adapter/blob/master/LICENSE.txt
