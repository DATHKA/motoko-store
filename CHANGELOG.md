# store changelog

# 0.2.0
* Added `fromMap` constructor for seeding stores from existing maps
* Renamed `exists` to `containsKey` and `indexSizeFor` to `indexSizeBy` for naming consistency
* Removed `countBy` in favor of `indexSizeBy`
* Reworked record removal: `delete` now returns the removed value while `remove` becomes void, in line with `Map` in `mo:core@1.0.0`
* Updated multiple query helpers (`keysBy*`, `valuesBy*`, `page*`) to return iterators instead of arrays
* Changed `filter` and `mapValues` to return iterators instead of arrays
* Expanded test suite to cover the full public API surface and new iterator behaviors

# 0.1.3
* Added `indexSize` and `indexExists` helper functions

# 0.1.2
* Added SortOrder type and ordering helpers for keys and value projections
* Added Store.indexExists and Store.indexSize utilities
* Expanded README with sorting examples and clearer inline guidance
* Updated tests to cover ordered key and value lookups

# 0.1.1
* Documentation improvement

# 0.1.0
* Initial release
* Added
* Store type
* Indexes
* Supporting CRUD functions
