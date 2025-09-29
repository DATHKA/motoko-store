Function valuesByOrder
func valuesByOrder<K, V, A>(store : Store<K, V>, compareKey : Compare<K>, indexName : IndexName, indexValue : Text, order : SortOrder, projector : V -> A, compareProjection : Compare<A>) : Result.Result<Iter.Iter<V>, StoreError>
Returns values for an index value ordered with a custom projection.

let valuesIter = Store.valuesByOrder(
  store,
  Text.compare,
  "index_status",
  "active",
  #descending,
  func v = v.balance,
  Nat.compare
);
Function pageValuesByOrder
func pageValuesByOrder<K, V, A>(store : Store<K, V>, compareKey : Compare<K>, indexName : IndexName, indexValue : Text, order : SortOrder, offset : Nat, limit : Nat, projector : V -> A, compareProjection : Compare<A>) : Result.Result<Iter.Iter<V>, StoreError>
Returns a paginated iterator of values ordered by a projection.

Function registerIndex
func registerIndex<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<(), StoreError>
Registers a new empty index. Existing records are unaffected until reindexed explicitly.

let registered = Store.registerIndex(store, "index_region");
// registered == #ok(()) and the store now tracks the new index
Function unregisterIndex
func unregisterIndex<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<(), StoreError>
Removes an index and all its key sets. Existing records remain stored but the index is no longer maintained.

let removed = Store.unregisterIndex(store, "index_region");
// removed == #ok(()) and the index name is no longer registered
Function indexNames
func indexNames<K, V>(store : Store<K, V>) : [IndexName]
Lists the registered index names in ascending (lexicographic) order.

let names = Store.indexNames(store);
// names might be ["index_status", "index_category"]
Function indexExists
func indexExists<K, V>(store : Store<K, V>, name : IndexName) : Bool
Returns true when an index with the given name is registered.

let present = Store.indexExists(store, "index_status");
// present == true when the index has been registered
Function indexKeys
func indexKeys<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<[Text], StoreError>
Lists key-set identifiers for a specific index in ascending order.

let keySets = Store.indexKeys(store, "index_status");
// keySets == #ok(["active", "inactive"])
Function indexSize
func indexSize<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<Nat, StoreError>
Returns the number of key sets tracked by a named index.

let size = Store.indexSize(store, "index_status");
// size == #ok(2) when two key sets exist
Function indexSizeFor
func indexSizeFor<K, V>(store : Store<K, V>, name : IndexName, indexValue : Text) : Result.Result<Nat, StoreError>
Returns the number of keys stored under indexValue inside indexName.

let total = Store.indexSizeFor(store, "index_status", "active");
// total == #ok(2) when two keys are indexed as active
Function reindexRecord
func reindexRecord<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K, oldPairs : [(IndexName, Text)], newPairs : [(IndexName, Text)]) : Result.Result<(), StoreError>
Updates index membership by replacing old key-set assignments with new ones. The key is removed from every set in oldPairs and inserted into each set in newPairs; both arguments typically originate from buildPairMapSubset.

let reindexed = Store.reindexRecord(store, Text.compare, "acct-2", [("index_status", "inactive")], [("index_status", "active")]);
// reindexed == #ok(()) after moving the key to the "active" set
Function rebuildIndex
func rebuildIndex<K, V>(store : Store<K, V>, compareKey : Compare<K>, name : IndexName, projector : V -> Text) : Result.Result<(), StoreError>
Rebuilds an index by projecting over all records, clearing existing key sets first. Useful when the logic that determines set keys has changed. The projector receives each record value and returns the set identifier to store it under.

let rebuilt = Store.rebuildIndex(store, Text.compare, "index_status", func v = v.status);
// rebuilt == #ok(()) and key sets now reflect projector output
Function verifyIndex
func verifyIndex<K, V>(store : Store<K, V>, compareKey : Compare<K>, name : Text, projector : V -> Text) : Result.Result<(), {#invalidIndex; #inconsistent : Nat}>
Verifies that an index matches a projector. Returns mismatch count when inconsistent. The projector must use the same logic as was used to populate the index initially.

let verified = Store.verifyIndex(store, Text.compare, "index_status", func v = v.status);
// verified == #ok(()) when key sets are aligned, otherwise #err(#inconsistent n)
Function filter
func filter<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : [V]
Returns all values that satisfy the predicate (key, value) -> Bool.

let actives = Store.filter(store, func (_, v) = v.status == "active");
// actives == [value1, value2] for matching records
Function find
func find<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : ?V
Returns the first value that satisfies the predicate (key, value) -> Bool.

let found = Store.find(store, func (_, v) = v.status == "inactive");
// found == ?value or null
Function any
func any<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : Bool
Checks whether any value satisfies the predicate (key, value) -> Bool.

let hasServices = Store.any(store, func (_, v) = v.category == "services");
// hasServices == true when predicate matches
Function mapValues
func mapValues<K, V, A>(store : Store<K, V>, f : (K, V) -> A) : [A]
Maps every record through f and collects the results.

let names = Store.mapValues<Text, StoreRecord, Text>(store, func (_, v) = v.name);
// names == ["Alpha", ...] representing derived projections