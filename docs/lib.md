# lib

## Type `Store`
``` motoko no-repl
type Store<K, V> = { name : Text; records : Map.Map<K, V>; index : Map.Map<IndexName, Index<K>> }
```

Mutable key-value store with optional secondary indexes.

A store keeps:
- `name` – descriptive label for logging and debugging.
- `records` – ordered `Map` from a comparable key `K` to value `V`.
- `index` – mapping from each registered `IndexName` to a set of keys that belong to that index.

# Example
```motoko
import Store "mo:store";
import Text "mo:core/Text";

type Merchant = {
  name : Text;
  status : Text;
  category : Text;
};

let store = Store.empty<Text, Merchant>("merchants");
ignore Store.registerIndex<Text, Merchant>(store, "index_status");
ignore Store.registerIndex<Text, Merchant>(store, "index_category");

ignore Store.add<Text, Merchant>(
  store,
  Text.compare,
  "acct-1",
{ name = "Alpha"; status = "active"; category = "hardware" },
  ?[("index_status", "active"), ("index_category", "hardware")]
);

let activeMerchants = switch (Store.valuesBy<Text, Merchant>(store, Text.compare, "index_status", "active")) {
  case (#ok merchants) merchants;
  case (#err _) [];
};
```

In the example above `"index_status"` and `"index_category"` are `IndexName` values provided at
initialisation time. Each subsequent call that manipulates indexes must supply the same
`IndexName` strings together with a set key (e.g. `"active"`) to place or retrieve
records from the corresponding indexed key set.

## Type `Compare`
``` motoko no-repl
type Compare<K> = (K, K) -> Order.Order
```


## Type `Index`
``` motoko no-repl
type Index<K> = { keySet : Map.Map<Text, Set.Set<K>> }
```

Internal structure representing key sets for an index.
```motoko
let idx = newEmptyIndex<Text>();
// idx.keySet.size() == 0
```

## Type `IndexName`
``` motoko no-repl
type IndexName = Text
```

Identifier used when referencing registered indexes within a store.

## Type `StoreError`
``` motoko no-repl
type StoreError = {#keyExists; #indexMismatch; #invalidIndex; #notFound; #indexExists}
```

Errors that can be returned by store operations.
Variants:
* `#keyExists` – attempted to add an already existing key.
* `#indexMismatch` – provided index pairs do not match registered indexes.
* `#invalidIndex` – referenced index name does not exist.
* `#notFound` – requested item or key set was not found.
* `#indexExists` – attempted to register an index that already exists.

## Function `empty`
``` motoko no-repl
func empty<K, V>(name : Text) : Store<K, V>
```

Creates a new store with optional pre-registered index names.
```motoko
let store = Store.empty<Text, Nat>("inventory");
```

## Function `exists`
``` motoko no-repl
func exists<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K) : Bool
```

Returns true when record `k` exists.
```motoko
let present = Store.exists(store, Text.compare, "acct-1");
// present == true when the key has been added
```

## Function `size`
``` motoko no-repl
func size<K, V>(store : Store<K, V>) : Nat
```

Returns the number of stored records.
```motoko
let total = Store.size(store);
// total == 3
```

## Function `clear`
``` motoko no-repl
func clear<K, V>(store : Store<K, V>)
```

Removes all records and clears all index key sets.
```motoko
Store.clear(store);
// Store.size(store) == 0
```

## Function `clearIndex`
``` motoko no-repl
func clearIndex<K, V>(store : Store<K, V>, name : Text) : Result.Result<(), StoreError>
```

Clears a single index by name.
```motoko
let cleared = Store.clearIndex(store, "index_status");
// cleared == #ok(()) when the index exists
```

## Function `add`
``` motoko no-repl
func add<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K, v : V, pairs : ?[(IndexName, Text)]) : Result.Result<(), StoreError>
```

Inserts a record enforcing that index pairs match registered indexes.
```motoko
let added = Store.add(store, Text.compare, "acct-1", record, ?[("index_status", "active")]);
// added == #ok(()) and the record now exists in `store.records`
```

## Function `put`
``` motoko no-repl
func put<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K, v : V, pairs : ?[(IndexName, Text)]) : Result.Result<?V, StoreError>
```

Upserts a record. Returns the previous value, if any, and optionally reindexes the key
when `pairs` is provided. New records in an indexed store must supply the full mapping;
existing records retain their current key sets when `pairs` is omitted.
```motoko
let putResult = Store.put(store, Text.compare, "acct-1", record, ?[("index_status", "active")]);
// putResult == #ok(null) and the record is stored with fresh index key sets
```

## Function `update`
``` motoko no-repl
func update<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K, f : V -> V, pairs : ?[(IndexName, Text)]) : Result.Result<V, StoreError>
```

Applies a transformer to an existing record and optionally reindexes it.
The transformer receives the current value and returns the replacement value.
When `pairs` is provided, the key is removed from all previous key sets and re-added
with the new mapping; when `pairs` is `null`, only the record value changes.
```motoko
let updated = Store.update(
  store,
  Text.compare,
  "acct-1",
  func r = { r with status = "inactive" },
  ?[("index_status", "inactive")]
);
// updated == #ok(newRecord) and the index key sets now reference "inactive"
```

## Function `renameKey`
``` motoko no-repl
func renameKey<K, V>(store : Store<K, V>, compareKey : Compare<K>, oldKey : K, newKey : K, value : V, pairs : ?[(IndexName, Text)]) : Result.Result<(), StoreError>
```

Renames a record key while keeping indexes consistent.
```motoko
let renamed = Store.renameKey(store, Text.compare, "acct-1", "acct-1a", record, null);
// renamed == #ok(()) and the new key replaces the old one in records and indexes
```

## Function `remove`
``` motoko no-repl
func remove<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K) : Result.Result<V, StoreError>
```

Removes a record and its index references.
```motoko
let removed = Store.remove(store, Text.compare, "acct-1");
// removed == #ok(oldValue) and the key disappears from all indexes
```

## Function `get`
``` motoko no-repl
func get<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K) : ?V
```

Retrieves a record by key.
```motoko
let maybe = Store.get(store, Text.compare, "acct-1");
// maybe == ?value when present
```

## Function `keys`
``` motoko no-repl
func keys<K, V>(store : Store<K, V>) : Iter.Iter<K>
```

Returns an iterator over all keys in ascending order.
```motoko
let keyIter = Store.keys(store);
// Iter.toArray(keyIter) lists every key
```

## Function `values`
``` motoko no-repl
func values<K, V>(store : Store<K, V>) : Iter.Iter<V>
```

Returns an iterator over all values in the order of their keys.
```motoko
let valueIter = Store.values(store);
// Iter.toArray(valueIter) lists every value
```

## Function `keysBy`
``` motoko no-repl
func keysBy<K, V>(store : Store<K, V>, indexName : IndexName, indexValue : Text) : Result.Result<[K], StoreError>
```

Returns keys found under a specific index value. The array mirrors the contents of the
key set at the time of the call.
```motoko
let keys = Store.keysBy(store, "index_status", "active");
// keys == #ok([...]) containing all matching account identifiers
```

## Function `valuesBy`
``` motoko no-repl
func valuesBy<K, V>(store : Store<K, V>, compareKey : Compare<K>, indexName : IndexName, indexValue : Text) : Result.Result<[V], StoreError>
```

Returns values found under a specific index value. The helper rehydrates each key and
reports `#err(#notFound)` if a key set contains stale keys.
```motoko
let vals = Store.valuesBy(store, Text.compare, "index_status", "active");
// vals == #ok([...]) and stale key sets trigger #err(#notFound)
```

## Function `countBy`
``` motoko no-repl
func countBy<K, V>(store : Store<K, V>, indexName : IndexName, indexValue : Text) : Result.Result<Nat, StoreError>
```

Counts the number of keys present for an index value.
```motoko
let total = Store.countBy(store, "index_status", "active");
// total == #ok(2) meaning two keys live in the set
```

## Function `firstBy`
``` motoko no-repl
func firstBy<K, V>(store : Store<K, V>, compareKey : Compare<K>, indexName : IndexName, indexValue : Text) : Result.Result<?V, StoreError>
```

Returns the first value under an index value, if present.
```motoko
let first = Store.firstBy(store, Text.compare, "index_status", "active");
// first == #ok(?value) where ?value is the lowest-key record
```

## Function `pageKeysBy`
``` motoko no-repl
func pageKeysBy<K, V>(store : Store<K, V>, indexName : IndexName, indexValue : Text, offset : Nat, limit : Nat) : Result.Result<[K], StoreError>
```

Returns a slice of keys for an index value using zero-based pagination.
`offset` skips the given number of matches, `limit` caps how many keys are returned.
Supplying `offset >= size` naturally produces an empty array.
```motoko
let page = Store.pageKeysBy(store, "index_status", "active", 0, 2);
// page == #ok(["acct-1", "acct-3"]) skipping 0 keys and returning at most 2
```

## Function `pageBy`
``` motoko no-repl
func pageBy<K, V>(store : Store<K, V>, compareKey : Compare<K>, indexName : IndexName, indexValue : Text, offset : Nat, limit : Nat) : Result.Result<[V], StoreError>
```

Returns a slice of values for an index value using zero-based pagination.
`offset` skips the given number of matches, `limit` caps how many values are returned.
The helper aborts with `#err(#notFound)` if any key-set entry fails to resolve.
```motoko
let page = Store.pageBy(store, Text.compare, "index_status", "active", 0, 1);
// page == #ok([value]) after skipping 0 keys and returning at most 1
```

## Function `registerIndex`
``` motoko no-repl
func registerIndex<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<(), StoreError>
```

Registers a new empty index. Existing records are unaffected until reindexed explicitly.
```motoko
let registered = Store.registerIndex(store, "index_region");
// registered == #ok(()) and the store now tracks the new index
```

## Function `unregisterIndex`
``` motoko no-repl
func unregisterIndex<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<(), StoreError>
```

Removes an index and all its key sets. Existing records remain stored but the index is
no longer maintained.
```motoko
let removed = Store.unregisterIndex(store, "index_region");
// removed == #ok(()) and the index name is no longer registered
```

## Function `indexNames`
``` motoko no-repl
func indexNames<K, V>(store : Store<K, V>) : [IndexName]
```

Lists the registered index names in ascending (lexicographic) order.
```motoko
let names = Store.indexNames(store);
// names might be ["index_status", "index_category"]
```

## Function `indexKeys`
``` motoko no-repl
func indexKeys<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<[Text], StoreError>
```

Lists key-set identifiers for a specific index in ascending order.
```motoko
let keySets = Store.indexKeys(store, "index_status");
// keySets == #ok(["active", "inactive"])
```

## Function `reindexRecord`
``` motoko no-repl
func reindexRecord<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K, oldPairs : [(IndexName, Text)], newPairs : [(IndexName, Text)]) : Result.Result<(), StoreError>
```

Updates index membership by replacing old key-set assignments with new ones.
The key is removed from every set in `oldPairs` and inserted into each set in
`newPairs`; both arguments typically originate from `buildPairMapSubset`.
```motoko
let reindexed = Store.reindexRecord(store, Text.compare, "acct-2", [("index_status", "inactive")], [("index_status", "active")]);
// reindexed == #ok(()) after moving the key to the "active" set
```

## Function `rebuildIndex`
``` motoko no-repl
func rebuildIndex<K, V>(store : Store<K, V>, compareKey : Compare<K>, name : IndexName, projector : V -> Text) : Result.Result<(), StoreError>
```

Rebuilds an index by projecting over all records, clearing existing key sets first.
Useful when the logic that determines set keys has changed. The `projector` receives
each record value and returns the set identifier to store it under.
```motoko
let rebuilt = Store.rebuildIndex(store, Text.compare, "index_status", func v = v.status);
// rebuilt == #ok(()) and key sets now reflect projector output
```

## Function `verifyIndex`
``` motoko no-repl
func verifyIndex<K, V>(store : Store<K, V>, compareKey : Compare<K>, name : Text, projector : V -> Text) : Result.Result<(), {#invalidIndex; #inconsistent : Nat}>
```

Verifies that an index matches a projector. Returns mismatch count when inconsistent.
The projector must use the same logic as was used to populate the index initially.
```motoko
let verified = Store.verifyIndex(store, Text.compare, "index_status", func v = v.status);
// verified == #ok(()) when key sets are aligned, otherwise #err(#inconsistent n)
```

## Function `filter`
``` motoko no-repl
func filter<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : [V]
```

Returns all values that satisfy the predicate `(key, value) -> Bool`.
```motoko
let actives = Store.filter(store, func (_, v) = v.status == "active");
// actives == [value1, value2] for matching records
```

## Function `find`
``` motoko no-repl
func find<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : ?V
```

Returns the first value that satisfies the predicate `(key, value) -> Bool`.
```motoko
let found = Store.find(store, func (_, v) = v.status == "inactive");
// found == ?value or null
```

## Function `any`
``` motoko no-repl
func any<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : Bool
```

Checks whether any value satisfies the predicate `(key, value) -> Bool`.
```motoko
let hasServices = Store.any(store, func (_, v) = v.category == "services");
// hasServices == true when predicate matches
```

## Function `mapValues`
``` motoko no-repl
func mapValues<K, V, A>(store : Store<K, V>, f : (K, V) -> A) : [A]
```

Maps every record through `f` and collects the results.
```motoko
let names = Store.mapValues<Text, StoreRecord, Text>(store, func (_, v) = v.name);
// names == ["Alpha", ...] representing derived projections
```
