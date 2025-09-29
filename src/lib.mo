import Map "mo:core/Map";
import Set "mo:core/Set";
import Order "mo:core/Order";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Nat "mo:core/Nat";

module {
  /// Mutable key-value store with optional secondary indexes.
  ///
  /// A store keeps:
  /// - `name` – descriptive label for logging and debugging.
  /// - `records` – ordered `Map` from a comparable key `K` to value `V`.
  /// - `index` – mapping from each registered `IndexName` to a set of keys that belong to that index.
  ///
  /// # Example
  /// ```motoko
  /// import Store "mo:store";
  /// import Text "mo:core/Text";
  ///
  /// type Merchant = {
  ///   name : Text;
  ///   status : Text;
  ///   category : Text;
  /// };
  ///
  /// let store = Store.empty<Text, Merchant>("merchants");
  /// ignore Store.registerIndex<Text, Merchant>(store, "index_status");
  /// ignore Store.registerIndex<Text, Merchant>(store, "index_category");
  ///
  /// ignore Store.add<Text, Merchant>(
  ///   store,
  ///   Text.compare,
  ///   "acct-1",
  ///   { name = "Alpha"; status = "active"; category = "hardware" },
  ///   ?[("index_status", "active"), ("index_category", "hardware")]
  /// );
  ///
  /// let activeMerchants = switch (Store.valuesBy<Text, Merchant>(store, Text.compare, "index_status", "active")) {
  ///   case (#ok merchants) merchants;
  ///   case (#err _) [];
  /// };
  /// ```
  ///
  /// In the example above `"index_status"` and `"index_category"` are `IndexName` values registered after
  /// initialisation. Each subsequent call that manipulates indexes must supply the same
  /// `IndexName` strings together with a set key (e.g. `"active"`) to place or retrieve
  /// records from the corresponding indexed key set.
  public type Store<K, V> = {
    name : Text;
    records : Map.Map<K, V>;
    index : Map.Map<IndexName, Index<K>>;
  };

  /// Comparator function signature used by store operations to order keys.
  public type Compare<K> = (K, K) -> Order.Order;

  /// Sorting direction used by helpers that support custom ordering.
  public type SortOrder = {
    #ascending;
    #descending;
  };

  /// Internal structure representing key sets for an index.
  /// ```motoko
  /// let idx = newEmptyIndex<Text>();
  /// // idx.keySet.size() == 0
  /// ```
  public type Index<K> = {
    keySet : Map.Map<Text, Set.Set<K>>;
  };

  /// Identifier used when referencing registered indexes within a store.
  public type IndexName = Text;

  /// Errors that can be returned by store operations.
  /// Variants:
  /// * `#keyExists` – attempted to add an already existing key.
  /// * `#indexMismatch` – provided index pairs do not match registered indexes.
  /// * `#invalidIndex` – referenced index name does not exist.
  /// * `#notFound` – requested item or key set was not found.
  /// * `#indexExists` – attempted to register an index that already exists.
  public type StoreError = {
    #keyExists;
    #indexMismatch;
    #invalidIndex;
    #notFound;
    #indexExists;
  };

  /// Creates a fresh index with no key sets.
  /// ```motoko
  /// let idx = newEmptyIndex<Text>();
  /// // Map.size(idx.keySet) == 0
  /// ```
  func newEmptyIndex<K>() : Index<K> = {
    keySet = Map.empty<Text, Set.Set<K>>();
  };

  /// Normalises a list of `(indexName, setKey)` tuples so that every registered index
  /// is mentioned exactly once and appears at most once. Unknown index names or duplicate
  /// entries cause `#invalidIndex` / `#indexMismatch` errors respectively.
  /// The returned map is keyed by index name and is used by `add` / `put` when onboarding
  /// a record into every index.
  /// ```motoko
  /// let pairs = [("index_status", "active"), ("index_region", "eu")];
  /// let normalized = buildPairMapExact(store, pairs);
  /// // normalized == #ok(map) and map.get("index_status") == ?"active"
  /// ```
  func buildPairMapExact<K, V>(store : Store<K, V>, pairs : [(IndexName, Text)]) : Result.Result<Map.Map<IndexName, Text>, StoreError> {
    let normalized = Map.empty<IndexName, Text>();
    for ((name, value) in Array.values(pairs)) {
      switch (Map.get(store.index, Text.compare, name)) {
        case null { return #err(#invalidIndex) };
        case (?_) {};
      };
      switch (Map.get(normalized, Text.compare, name)) {
        case null {};
        case (?_) { return #err(#indexMismatch) };
      };
      Map.add(normalized, Text.compare, name, value);
    };
    if (Map.size(normalized) != Map.size(store.index)) {
      return #err(#indexMismatch);
    };
    #ok(normalized);
  };

  /// Normalises a subset of `(indexName, setKey)` tuples without requiring full coverage.
  /// The subset must reference existing indexes and remain free of duplicates.
  /// Useful when moving a key between only a few key sets (e.g. inside `reindexRecord`).
  /// ```motoko
  /// let subset = [("index_status", "inactive")];
  /// let normalized = buildPairMapSubset(store, subset);
  /// // normalized == #ok(map) with map.get("index_status") == ?"inactive"
  /// ```
  func buildPairMapSubset<K, V>(store : Store<K, V>, pairs : [(IndexName, Text)]) : Result.Result<Map.Map<IndexName, Text>, StoreError> {
    let normalized = Map.empty<IndexName, Text>();
    for ((name, value) in Array.values(pairs)) {
      switch (Map.get(store.index, Text.compare, name)) {
        case null { return #err(#invalidIndex) };
        case (?_) {};
      };
      switch (Map.get(normalized, Text.compare, name)) {
        case null {};
        case (?_) { return #err(#indexMismatch) };
      };
      Map.add(normalized, Text.compare, name, value);
    };
    #ok(normalized);
  };

  /// Ensures callers provide a complete mapping of indexes to set keys when required.
  /// Returns the normalised map or the appropriate error when coverage is incomplete.
  /// When the store has no registered indexes, an empty map is returned regardless of input.
  /// `add` and `put` rely on this helper to enforce index coverage for new keys.
  /// ```motoko
  /// let normalized = requireIndexPairs(store, ?[("index_status", "active"), ("index_region", "eu")]);
  /// // normalized == #ok(map) only when store has exactly those indexes
  /// ```
  func requireIndexPairs<K, V>(store : Store<K, V>, pairs : ?[(IndexName, Text)]) : Result.Result<Map.Map<IndexName, Text>, StoreError> {
    let indexCount = Map.size(store.index);
    if (indexCount == 0) {
      switch (pairs) {
        case null { return #ok(Map.empty<IndexName, Text>()); };
        case (?values) {
          if (values.size() == 0) {
            return #ok(Map.empty<IndexName, Text>());
          };
          return #err(#indexMismatch);
        };
      };
    };
    switch (pairs) {
      case null { #err(#indexMismatch) };
      case (?values) { buildPairMapExact(store, values) };
    };
  };

  /// Adds a key to each indexed key set described by `pairs`.
  /// ```motoko
  /// addKeyToIndexes(store, "acct-1", pairMap);
  /// // key now appears in each referenced set
  /// ```
  func addKeyToIndexes<K, V>(store : Store<K, V>, compareKey : Compare<K>, key : K, pairs : Map.Map<IndexName, Text>) {
    for (entry in Map.entries(pairs)) {
      let (indexName, setKey) = entry;
      switch (Map.get(store.index, Text.compare, indexName)) {
        case null {};
        case (?idx) {
          switch (Map.get(idx.keySet, Text.compare, setKey)) {
            case null {
              let set = Set.empty<K>();
              Set.add(set, compareKey, key);
              Map.add(idx.keySet, Text.compare, setKey, set);
            };
            case (?set) {
              Set.add(set, compareKey, key);
            };
          };
        };
      };
    };
  };

  /// Removes a key from the index key sets listed in `pairs`.
  /// ```motoko
  /// removeKeyFromKeySets(store, "acct-1", pairMap);
  /// // key removed from each mapped set
  /// ```
  func removeKeyFromKeySets<K, V>(store : Store<K, V>, compareKey : Compare<K>, key : K, pairs : Map.Map<IndexName, Text>) {
    for (entry in Map.entries(pairs)) {
      let (indexName, setKey) = entry;
      switch (Map.get(store.index, Text.compare, indexName)) {
        case null {};
        case (?idx) {
          switch (Map.get(idx.keySet, Text.compare, setKey)) {
            case null {};
            case (?set) {
              Set.remove(set, compareKey, key);
              if (Set.size(set) == 0) {
                Map.remove(idx.keySet, Text.compare, setKey);
              };
            };
          };
        };
      };
    };
  };

  /// Removes a key from every key set across all indexes.
  /// ```motoko
  /// removeKeyFromAllIndexes(store, "acct-1");
  /// // key no longer present in any index key set
  /// ```
  func removeKeyFromAllIndexes<K, V>(store : Store<K, V>, compareKey : Compare<K>, key : K) {
    for (entry in Map.entries(store.index)) {
      let (_, idx) = entry;
      let setNames = Iter.toArray(Map.keys(idx.keySet));
      for (setName in setNames.vals()) {
        switch (Map.get(idx.keySet, Text.compare, setName)) {
          case null {};
          case (?set) {
            Set.remove(set, compareKey, key);
            if (Set.size(set) == 0) {
              Map.remove(idx.keySet, Text.compare, setName);
            };
          };
        };
      };
    };
  };

  /// Collects the key-set assignment for a key across every registered index.
  /// Used when migrating a key and the existing key-set arrangement must be preserved.
  /// Returns an empty map when the key is unindexed or when the store has no indexes.
  /// ```motoko
  /// let pairs = collectIndexPairsForKey(store, Text.compare, "acct-1");
  /// // Map.size(pairs) equals number of indexes containing the key
  /// ```
  func collectIndexPairsForKey<K, V>(store : Store<K, V>, compareKey : Compare<K>, key : K) : Map.Map<IndexName, Text> {
    let pairs = Map.empty<IndexName, Text>();
    for (entry in Map.entries(store.index)) {
      let (indexName, idx) = entry;
      var located = false;
      let setNames = Iter.toArray(Map.keys(idx.keySet));
      label scanSets for (setName in setNames.vals()) {
        if (located) { continue scanSets };
        switch (Map.get(idx.keySet, Text.compare, setName)) {
          case null {};
          case (?set) {
            if (Set.contains(set, compareKey, key)) {
              Map.add(pairs, Text.compare, indexName, setName);
              located := true;
            };
          };
        };
      };
    };
    pairs;
  };

  /// Safe subtraction that never underflows.
  /// ```motoko
  /// safeSub(5, 3) // == 2
  /// safeSub(3, 5) // == 0
  /// ```
  func safeSub(a : Nat, b : Nat) : Nat{
    if (a >= b) a-b else 0;
  };

  /// Returns a slice of `items` respecting bounds using zero-based pagination.
  /// `offset` is the number of elements to skip, `limit` caps the number of returned items
  /// (a `limit` of `0` yields an empty array).
  /// ```motoko
  /// paginateArray([1,2,3,4], 1, 2) // == [2,3]
  /// ```
  func paginateArray<T>(items : [T], offset : Nat, limit : Nat) : [T] {
    let size = items.size();
    if (offset >= size or limit == 0) {
      return Array.empty<T>();
    };
    let endExclusive = Nat.min(size, offset + limit);
    let length = safeSub(endExclusive, offset);
    Array.tabulate<T>(length, func i = items[offset + i]);
  };

  /// Returns a new array with items in reverse order.
  func reverseArray<T>(items : [T]) : [T] {
    let size = items.size();
    Array.tabulate<T>(size, func i = items[size - 1 - i]);
  };

  /// Applies the requested sort order to an array of items.
  func applySortOrder<T>(items : [T], order : SortOrder) : [T] {
    switch (order) {
      case (#ascending) { items };
      case (#descending) { reverseArray(items) };
    }
  };

  /// Creates a new store with no records and no indexes.
  /// ```motoko
  /// let store = Store.empty<Text, Nat>("inventory");
  /// // Store.size(store) == 0 and Store.indexNames(store) == []
  /// ```
  public func empty<K, V>(
    name : Text
  ) : Store<K, V> {
    let store : Store<K, V> = {
      name = name;
      records = Map.empty<K, V>();
      index = Map.empty<IndexName, Index<K>>();
    };
    store;
  };

  /// Returns true when record `k` exists.
  /// ```motoko
  /// let present = Store.exists(store, Text.compare, "acct-1");
  /// // present == true when the key has been added
  /// ```
  public func exists<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K) : Bool {
    Map.containsKey(store.records, compareKey, k);
  };

  /// Returns the number of stored records.
  /// ```motoko
  /// let total = Store.size(store);
  /// // total == 3
  /// ```
  public func size<K, V>(store : Store<K, V>) : Nat {
    Map.size(store.records);
  };

  /// Removes all records and clears all index key sets.
  /// ```motoko
  /// Store.clear(store);
  /// // Store.size(store) == 0
  /// ```
  public func clear<K, V>(store : Store<K, V>) {
    Map.clear(store.records);
    for (entry in Map.entries(store.index)) {
      let (_, idx) = entry;
      Map.clear(idx.keySet);
    };
  };

  /// Clears a single index by name.
  /// ```motoko
  /// let cleared = Store.clearIndex(store, "index_status");
  /// // cleared == #ok(()) when the index exists
  /// ```
  public func clearIndex<K, V>(store : Store<K, V>, name : Text) : Result.Result<(), StoreError> {
    switch (Map.get(store.index, Text.compare, name)) {
      case null { #err(#invalidIndex) };
      case (?idx) {
        Map.clear(idx.keySet);
        #ok(())
      };
    };
  };

  /// Inserts a record enforcing that index pairs match registered indexes.
  /// ```motoko
  /// let added = Store.add(store, Text.compare, "acct-1", record, ?[("index_status", "active")]);
  /// // added == #ok(()) and the record now exists in `store.records`
  /// ```
  public func add<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K, v : V, pairs : ?[(IndexName, Text)]) : Result.Result<(), StoreError> {
    if (exists(store, compareKey, k)) {
      return #err(#keyExists);
    };
    let normalized = switch (requireIndexPairs(store, pairs)) {
      case (#err e) { return #err e };
      case (#ok map) { map };
    };
    Map.add(store.records, compareKey, k, v);
    addKeyToIndexes(store, compareKey, k, normalized);
    #ok(())
  };

  /// Upserts a record. Returns the previous value, if any, and optionally reindexes the key
  /// when `pairs` is provided. New records in an indexed store must supply the full mapping;
  /// existing records retain their current key sets when `pairs` is omitted.
  /// ```motoko
  /// let putResult = Store.put(store, Text.compare, "acct-1", record, ?[("index_status", "active")]);
  /// // putResult == #ok(null) and the record is stored with fresh index key sets
  /// ```
  public func put<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K, v : V, pairs : ?[(IndexName, Text)]) : Result.Result<?V, StoreError> {
    let existing = Map.get(store.records, compareKey, k);
    let indexCount = Map.size(store.index);
    var normalized : ?Map.Map<IndexName, Text> = null;
    let hasExisting = switch (existing) {
      case null false;
      case (?_) true;
    };

    switch (pairs) {
      case null {
        if (indexCount > 0 and not hasExisting) {
          return #err(#indexMismatch);
        };
      };
      case (?values) {
        normalized := switch (buildPairMapExact(store, values)) {
          case (#err e) { return #err e };
          case (#ok map) { ?map };
        };
      };
    };

    switch (normalized) {
      case (?_) {
        if (hasExisting) { removeKeyFromAllIndexes(store, compareKey, k) };
      };
      case null {};
    };

    Map.add(store.records, compareKey, k, v);

    switch (normalized) {
      case (?map) { addKeyToIndexes(store, compareKey, k, map) };
      case null {};
    };

    #ok(existing);
  };

  /// Applies a transformer to an existing record and optionally reindexes it.
  /// The transformer receives the current value and returns the replacement value.
  /// When `pairs` is provided, the key is removed from all previous key sets and re-added
  /// with the new mapping; when `pairs` is `null`, only the record value changes.
  /// ```motoko
  /// let updated = Store.update(
  ///   store,
  ///   Text.compare,
  ///   "acct-1",
  ///   func r = { r with status = "inactive" },
  ///   ?[("index_status", "inactive")]
  /// );
  /// // updated == #ok(newRecord) and the index key sets now reference "inactive"
  /// ```
  public func update<K, V>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    k : K,
    f : V -> V,
    pairs : ?[(IndexName, Text)]
  ) : Result.Result<V, StoreError> {
    let current = switch (Map.get(store.records, compareKey, k)) {
      case null { return #err(#notFound) };
      case (?value) { value };
    };

    var newPairs : ?Map.Map<IndexName, Text> = null;
    switch (pairs) {
      case null {};
      case (?values) {
        switch (buildPairMapExact(store, values)) {
          case (#err e) { return #err e };
          case (#ok map) { newPairs := ?map };
        };
      };
    };

    switch (newPairs) {
      case (?_) { removeKeyFromAllIndexes(store, compareKey, k); };
      case null {};
    };

    let updated = f(current);
    Map.add(store.records, compareKey, k, updated);

    switch (newPairs) {
      case (?map) { addKeyToIndexes(store, compareKey, k, map); };
      case null {};
    };

    #ok(updated);
  };

  /// Renames a record key while keeping indexes consistent.
  /// ```motoko
  /// let renamed = Store.renameKey(store, Text.compare, "acct-1", "acct-1a", record, null);
  /// // renamed == #ok(()) and the new key replaces the old one in records and indexes
  /// ```
  public func renameKey<K, V>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    oldKey : K,
    newKey : K,
    value : V,
    pairs : ?[(IndexName, Text)]
  ) : Result.Result<(), StoreError> {
    switch (Map.get(store.records, compareKey, oldKey)) {
      case null { return #err(#notFound) };
      case (?_) {};
    };
    switch (Map.get(store.records, compareKey, newKey)) {
      case null {};
      case (?_) { return #err(#keyExists) };
    };

    let indexPairs = switch (pairs) {
      case null { collectIndexPairsForKey(store, compareKey, oldKey) };
      case (?values) {
        switch (buildPairMapExact(store, values)) {
          case (#err e) { return #err e };
          case (#ok map) { map };
        }
      };
    };

    ignore Map.delete(store.records, compareKey, oldKey);
    removeKeyFromAllIndexes(store, compareKey, oldKey);
    Map.add(store.records, compareKey, newKey, value);
    addKeyToIndexes(store, compareKey, newKey, indexPairs);
    #ok(());
  };

  /// Removes a record and its index references.
  /// ```motoko
  /// let removed = Store.remove(store, Text.compare, "acct-1");
  /// // removed == #ok(oldValue) and the key disappears from all indexes
  /// ```
  public func remove<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K) : Result.Result<V, StoreError> {
    let existing = Map.get(store.records, compareKey, k);
    switch (existing) {
      case null { #err(#notFound) };
      case (?value) {
        Map.remove(store.records, compareKey, k);
        removeKeyFromAllIndexes(store, compareKey, k);
        #ok(value)
      };
    };
  };

  /// Retrieves a record by key.
  /// ```motoko
  /// let maybe = Store.get(store, Text.compare, "acct-1");
  /// // maybe == ?value when present
  /// ```
  public func get<K, V>(store : Store<K, V>, compareKey : Compare<K>, k : K) : ?V {
    Map.get(store.records, compareKey, k);
  };

  /// Returns an iterator over all keys in ascending order.
  /// ```motoko
  /// let keyIter = Store.keys(store);
  /// // Iter.toArray(keyIter) lists every key
  /// ```
  public func keys<K, V>(store : Store<K, V>) : Iter.Iter<K> {
    Map.keys(store.records);
  };

  /// Returns an iterator over all values in the order of their keys.
  /// ```motoko
  /// let valueIter = Store.values(store);
  /// // Iter.toArray(valueIter) lists every value
  /// ```
  public func values<K, V>(store : Store<K, V>) : Iter.Iter<V> {
    Map.values(store.records);
  };

  /// Returns keys found under a specific index value. The array mirrors the contents of the
  /// key set at the time of the call.
  /// ```motoko
  /// let keys = Store.keysBy(store, "index_status", "active");
  /// // keys == #ok([...]) containing all matching account identifiers
  /// ```
  public func keysBy<K, V>(store : Store<K, V>, indexName : IndexName, indexValue : Text) : Result.Result<[K], StoreError> {
    let idx = switch (Map.get(store.index, Text.compare, indexName)) {
      case null { return #err(#invalidIndex) };
      case (?value) { value };
    };
    switch (Map.get(idx.keySet, Text.compare, indexValue)) {
      case null { #ok(Array.empty<K>()) };
      case (?set) { #ok(Iter.toArray(Set.values(set))) };
    };
  };

  /// Returns keys for an index value ordered according to `order`.
  /// ```motoko
  /// let keys = Store.keysByOrder(store, "index_status", "active", #descending);
  /// // keys == #ok(["acct-3", "acct-1"])
  /// ```
  public func keysByOrder<K, V>(store : Store<K, V>, indexName : IndexName, indexValue : Text, order : SortOrder) : Result.Result<[K], StoreError> {
    switch (keysBy(store, indexName, indexValue)) {
      case (#err e) { #err e };
      case (#ok keysAtIndex) { #ok(applySortOrder(keysAtIndex, order)) };
    }
  };

  /// Returns values found under a specific index value. The helper rehydrates each key and
  /// reports `#err(#notFound)` if a key set contains stale keys.
  /// ```motoko
  /// let vals = Store.valuesBy(store, Text.compare, "index_status", "active");
  /// // vals == #ok([...]) and stale key sets trigger #err(#notFound)
  /// ```
  public func valuesBy<K, V>(store : Store<K, V>, compareKey : Compare<K>, indexName : IndexName, indexValue : Text) : Result.Result<[V], StoreError> {
    switch (keysBy(store, indexName, indexValue)) {
      case (#err e) { #err e };
      case (#ok keysAtIndex) {
        let collected = List.empty<V>();
        for (key in keysAtIndex.vals()) {
          switch (Map.get(store.records, compareKey, key)) {
            case null { return #err(#notFound) };
            case (?value) { List.add(collected, value) };
          };
        };
        #ok(List.toArray(collected))
      };
    };
  };

  /// Counts the number of keys present for an index value.
  /// ```motoko
  /// let total = Store.countBy(store, "index_status", "active");
  /// // total == #ok(2) meaning two keys live in the set
  /// ```
  public func countBy<K, V>(store : Store<K, V>, indexName : IndexName, indexValue : Text) : Result.Result<Nat, StoreError> {
    let idx = switch (Map.get(store.index, Text.compare, indexName)) {
      case null { return #err(#invalidIndex) };
      case (?value) { value };
    };
    switch (Map.get(idx.keySet, Text.compare, indexValue)) {
      case null { #ok(0) };
      case (?set) { #ok(Set.size(set)) };
    };
  };

  /// Returns the first value under an index value, if present.
  /// ```motoko
  /// let first = Store.firstBy(store, Text.compare, "index_status", "active");
  /// // first == #ok(?value) where ?value is the lowest-key record
  /// ```
  public func firstBy<K, V>(store : Store<K, V>, compareKey : Compare<K>, indexName : IndexName, indexValue : Text) : Result.Result<?V, StoreError> {
    let idx = switch (Map.get(store.index, Text.compare, indexName)) {
      case null { return #err(#invalidIndex) };
      case (?value) { value };
    };
    switch (Map.get(idx.keySet, Text.compare, indexValue)) {
      case null { #ok(null) };
      case (?set) {
        let iterator = Set.values(set);
        switch (iterator.next()) {
          case null { #ok(null) };
          case (?key) { #ok(Map.get(store.records, compareKey, key)) };
        }
      };
    };
  };

  /// Returns a slice of keys for an index value using zero-based pagination.
  /// `offset` skips the given number of matches, `limit` caps how many keys are returned.
  /// Supplying `offset >= size` naturally produces an empty array.
  /// ```motoko
  /// let page = Store.pageKeysBy(store, "index_status", "active", 0, 2);
  /// // page == #ok(["acct-1", "acct-3"]) skipping 0 keys and returning at most 2
  /// ```
  public func pageKeysBy<K, V>(
    store : Store<K, V>,
    indexName : IndexName,
    indexValue : Text,
    offset : Nat,
    limit : Nat
  ) : Result.Result<[K], StoreError> {
    switch (keysBy(store, indexName, indexValue)) {
      case (#err e) { #err e };
      case (#ok keysAtIndex) { #ok(paginateArray(keysAtIndex, offset, limit)) };
    };
  };

  /// Returns a slice of keys for an index value after applying the desired order.
  /// ```motoko
  /// let page = Store.pageKeysByOrder(store, "index_status", "active", #descending, 0, 2);
  /// // page == #ok(["acct-3", "acct-1"])
  /// ```
  public func pageKeysByOrder<K, V>(
    store : Store<K, V>,
    indexName : IndexName,
    indexValue : Text,
    order : SortOrder,
    offset : Nat,
    limit : Nat
  ) : Result.Result<[K], StoreError> {
    switch (keysByOrder(store, indexName, indexValue, order)) {
      case (#err e) { #err e };
      case (#ok orderedKeys) { #ok(paginateArray(orderedKeys, offset, limit)) };
    };
  };

  /// Returns a slice of values for an index value using zero-based pagination.
  /// `offset` skips the given number of matches, `limit` caps how many values are returned.
  /// The helper aborts with `#err(#notFound)` if any key-set entry fails to resolve.
  /// ```motoko
  /// let page = Store.pageBy(store, Text.compare, "index_status", "active", 0, 1);
  /// // page == #ok([value]) after skipping 0 keys and returning at most 1
  /// ```
  public func pageBy<K, V>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    indexName : IndexName,
    indexValue : Text,
    offset : Nat,
    limit : Nat
  ) : Result.Result<[V], StoreError> {
    switch (pageKeysBy(store, indexName, indexValue, offset, limit)) {
      case (#err e) { #err e };
      case (#ok keysAtIndex) {
        let collected = List.empty<V>();
        for (key in keysAtIndex.vals()) {
          switch (Map.get(store.records, compareKey, key)) {
            case null { return #err(#notFound) };
            case (?value) { List.add(collected, value) };
          };
        };
        #ok(List.toArray(collected))
      };
    };
  };

  func sortKeysByProjection<K, V, A>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    keys : [K],
    order : SortOrder,
    projector : (K, V) -> A,
    compareProjection : Compare<A>
  ) : Result.Result<[K], StoreError> {
    let decoratedList = List.empty<(K, A)>();
    for (key in keys.vals()) {
      switch (Map.get(store.records, compareKey, key)) {
        case null { return #err(#notFound) };
        case (?value) {
          List.add(decoratedList, (key, projector(key, value)));
        };
      };
    };
    let decorated = Array.sort<(K, A)>(
      List.toArray(decoratedList),
      func (left, right) {
        switch (compareProjection(left.1, right.1)) {
          case (#equal) { compareKey(left.0, right.0) };
          case orderResult { orderResult };
        }
      }
    );
    let sortedKeys = Array.tabulate<K>(decorated.size(), func i = decorated[i].0);
    #ok(applySortOrder(sortedKeys, order));
  };

  /// Returns keys underneath an index sorted by a projection of their values.
  /// Ties fall back to the key comparator.
  /// ```motoko
  /// let sorted = Store.keysByValue(store, Text.compare, "index_status", "active", #ascending, func (_, acc) = acc.balance, Nat.compare);
  /// ```
  public func keysByValue<K, V, A>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    indexName : IndexName,
    indexValue : Text,
    order : SortOrder,
    projector : (K, V) -> A,
    compareProjection : Compare<A>
  ) : Result.Result<[K], StoreError> {
    switch (keysBy(store, indexName, indexValue)) {
      case (#err e) { #err e };
      case (#ok keysAtIndex) {
        sortKeysByProjection(store, compareKey, keysAtIndex, order, projector, compareProjection)
      };
    }
  };

  /// Returns a paginated slice of keys sorted by a projection of their values.
  /// ```motoko
  /// let page = Store.pageKeysByValue(store, Text.compare, "index_status", "active", #descending, 0, 2, func (_, acc) = acc.balance, Nat.compare);
  /// ```
  public func pageKeysByValue<K, V, A>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    indexName : IndexName,
    indexValue : Text,
    order : SortOrder,
    offset : Nat,
    limit : Nat,
    projector : (K, V) -> A,
    compareProjection : Compare<A>
  ) : Result.Result<[K], StoreError> {
    switch (keysByValue(store, compareKey, indexName, indexValue, order, projector, compareProjection)) {
      case (#err e) { #err e };
      case (#ok orderedKeys) { #ok(paginateArray(orderedKeys, offset, limit)) };
    }
  };

  /// Registers a new empty index. Existing records are unaffected until reindexed explicitly.
  /// ```motoko
  /// let registered = Store.registerIndex(store, "index_region");
  /// // registered == #ok(()) and the store now tracks the new index
  /// ```
  public func registerIndex<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<(), StoreError> {
    switch (Map.get(store.index, Text.compare, name)) {
      case null {};
      case (?_) { return #err(#indexExists) };
    };
    Map.add(store.index, Text.compare, name, newEmptyIndex<K>());
    #ok(());
  };

  /// Removes an index and all its key sets. Existing records remain stored but the index is
  /// no longer maintained.
  /// ```motoko
  /// let removed = Store.unregisterIndex(store, "index_region");
  /// // removed == #ok(()) and the index name is no longer registered
  /// ```
  public func unregisterIndex<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<(), StoreError> {
    if (not Map.delete(store.index, Text.compare, name)) {
      return #err(#invalidIndex);
    };
    #ok(());
  };

  /// Lists the registered index names in ascending (lexicographic) order.
  /// ```motoko
  /// let names = Store.indexNames(store);
  /// // names might be ["index_status", "index_category"]
  /// ```
  public func indexNames<K, V>(store : Store<K, V>) : [IndexName] {
    Iter.toArray(Map.keys(store.index));
  };

  /// Returns `true` when an index with the given name is registered.
  /// ```motoko
  /// let present = Store.indexExists(store, "index_status");
  /// // present == true when the index has been registered
  /// ```
  public func indexExists<K, V>(store : Store<K, V>, name : IndexName) : Bool {
    switch (Map.get(store.index, Text.compare, name)) {
      case null false;
      case (?_) true;
    }
  };

  /// Lists key-set identifiers for a specific index in ascending order.
  /// ```motoko
  /// let keySets = Store.indexKeys(store, "index_status");
  /// // keySets == #ok(["active", "inactive"])
  /// ```
  public func indexKeys<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<[Text], StoreError> {
    switch (Map.get(store.index, Text.compare, name)) {
      case null { #err(#invalidIndex) };
      case (?idx) { #ok(Iter.toArray(Map.keys(idx.keySet))) };
    };
  };

  /// Returns the number of key sets tracked by a named index.
  /// ```motoko
  /// let size = Store.indexSize(store, "index_status");
  /// // size == #ok(2) when two key sets exist
  /// ```
  public func indexSize<K, V>(store : Store<K, V>, name : IndexName) : Result.Result<Nat, StoreError> {
    switch (Map.get(store.index, Text.compare, name)) {
      case null { #err(#invalidIndex) };
      case (?idx) { #ok(Map.size(idx.keySet)) };
    }
  };

  /// Updates index membership by replacing old key-set assignments with new ones.
  /// The key is removed from every set in `oldPairs` and inserted into each set in
  /// `newPairs`; both arguments typically originate from `buildPairMapSubset`.
  /// ```motoko
  /// let reindexed = Store.reindexRecord(store, Text.compare, "acct-2", [("index_status", "inactive")], [("index_status", "active")]);
  /// // reindexed == #ok(()) after moving the key to the "active" set
  /// ```
  public func reindexRecord<K, V>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    k : K,
    oldPairs : [(IndexName, Text)],
    newPairs : [(IndexName, Text)]
  ) : Result.Result<(), StoreError> {
    switch (Map.get(store.records, compareKey, k)) {
      case null { return #err(#notFound) };
      case (?_) {};
    };
    let oldMap = switch (buildPairMapSubset(store, oldPairs)) {
      case (#err e) { return #err e };
      case (#ok map) { map };
    };
    let newMap = switch (buildPairMapSubset(store, newPairs)) {
      case (#err e) { return #err e };
      case (#ok map) { map };
    };
    removeKeyFromKeySets(store, compareKey, k, oldMap);
    addKeyToIndexes(store, compareKey, k, newMap);
    #ok(());
  };

  /// Rebuilds an index by projecting over all records, clearing existing key sets first.
  /// Useful when the logic that determines set keys has changed. The `projector` receives
  /// each record value and returns the set identifier to store it under.
  /// ```motoko
  /// let rebuilt = Store.rebuildIndex(store, Text.compare, "index_status", func v = v.status);
  /// // rebuilt == #ok(()) and key sets now reflect projector output
  /// ```
  public func rebuildIndex<K, V>(store : Store<K, V>, compareKey : Compare<K>, name : IndexName, projector : V -> Text) : Result.Result<(), StoreError> {
    let idx = switch (Map.get(store.index, Text.compare, name)) {
      case null { return #err(#invalidIndex) };
      case (?value) { value };
    };
    Map.clear(idx.keySet);
    for (entry in Map.entries(store.records)) {
      let (key, value) = entry;
      let setName = projector(value);
      switch (Map.get(idx.keySet, Text.compare, setName)) {
        case null {
          let set = Set.empty<K>();
          Set.add(set, compareKey, key);
          Map.add(idx.keySet, Text.compare, setName, set);
        };
        case (?set) {
          Set.add(set, compareKey, key);
        };
      };
    };
    #ok(());
  };

  /// Verifies that an index matches a projector. Returns mismatch count when inconsistent.
  /// The projector must use the same logic as was used to populate the index initially.
  /// ```motoko
  /// let verified = Store.verifyIndex(store, Text.compare, "index_status", func v = v.status);
  /// // verified == #ok(()) when key sets are aligned, otherwise #err(#inconsistent n)
  /// ```
  public func verifyIndex<K, V>(
    store : Store<K, V>,
    compareKey : Compare<K>,
    name : Text,
    projector : V -> Text
  ) : Result.Result<(), { #invalidIndex; #inconsistent : Nat }> {
    let idx = switch (Map.get(store.index, Text.compare, name)) {
      case null { return #err(#invalidIndex) };
      case (?value) { value };
    };

    let flagged = Set.empty<K>();
    var mismatch : Nat = 0;

    func flag(key : K) {
      if (not Set.contains(flagged, compareKey, key)) {
        Set.add(flagged, compareKey, key);
        mismatch += 1;
      };
    };

    for (entry in Map.entries(store.records)) {
      let (key, value) = entry;
      let setName = projector(value);
      switch (Map.get(idx.keySet, Text.compare, setName)) {
        case null { flag(key) };
        case (?set) {
          if (not Set.contains(set, compareKey, key)) {
            flag(key);
          };
        };
      };
    };

    for (setEntry in Map.entries(idx.keySet)) {
      let (setName, set) = setEntry;
      for (key in Set.values(set)) {
        switch (Map.get(store.records, compareKey, key)) {
          case null { flag(key) };
          case (?value) {
            if (setName != projector(value)) {
              flag(key);
            };
          };
        };
      };
    };

    if (mismatch == 0) {
      #ok(())
    } else {
      #err(#inconsistent(mismatch))
    };
  };

  /// Returns all values that satisfy the predicate `(key, value) -> Bool`.
  /// ```motoko
  /// let actives = Store.filter(store, func (_, v) = v.status == "active");
  /// // actives == [value1, value2] for matching records
  /// ```
  public func filter<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : [V] {
    let acc = List.empty<V>();
    for (entry in Map.entries(store.records)) {
      let (key, value) = entry;
      if (pred(key, value)) {
        List.add(acc, value);
      };
    };
    List.toArray(acc);
  };

  /// Returns the first value that satisfies the predicate `(key, value) -> Bool`.
  /// ```motoko
  /// let found = Store.find(store, func (_, v) = v.status == "inactive");
  /// // found == ?value or null
  /// ```
  public func find<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : ?V {
    for (entry in Map.entries(store.records)) {
      let (key, value) = entry;
      if (pred(key, value)) {
        return ?value;
      };
    };
    null;
  };

  /// Checks whether any value satisfies the predicate `(key, value) -> Bool`.
  /// ```motoko
  /// let hasServices = Store.any(store, func (_, v) = v.category == "services");
  /// // hasServices == true when predicate matches
  /// ```
  public func any<K, V>(store : Store<K, V>, pred : (K, V) -> Bool) : Bool {
    switch (find(store, pred)) {
      case null false;
      case (?_) true;
    }
  };

  /// Maps every record through `f` and collects the results.
  /// ```motoko
  /// let names = Store.mapValues<Text, StoreRecord, Text>(store, func (_, v) = v.name);
  /// // names == ["Alpha", ...] representing derived projections
  /// ```
  public func mapValues<K, V, A>(store : Store<K, V>, f : (K, V) -> A) : [A] {
    let acc = List.empty<A>();
    for (entry in Map.entries(store.records)) {
      let (key, value) = entry;
      List.add(acc, f(key, value));
    };
    List.toArray(acc);
  };
};
