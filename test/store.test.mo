import { test } "mo:test";
import Store "../src/";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Nat "mo:core/Nat";

type StoreRecord = {
  name : Text;
  status : Text;
  category : Text;
};

func record(name : Text, status : Text, category : Text) : StoreRecord {
  { name; status; category };
};

func assertContains(values : [Text], needle : Text) {
  assert Array.indexOf<Text>(values, Text.equal, needle) != null;
};

test("Store core CRUD and indexing", func () {
  let store = Store.empty<Text, StoreRecord>("merchant-store");

  ignore Store.registerIndex<Text, StoreRecord>(store, "index_status");
  ignore Store.registerIndex<Text, StoreRecord>(store, "index_category");

  assert Store.size<Text, StoreRecord>(store) == 0;
  assert not Store.exists<Text, StoreRecord>(store, Text.compare, "acct-1");
  assert Store.indexExists<Text, StoreRecord>(store, "index_status");
  assert Store.indexExists<Text, StoreRecord>(store, "index_category");
  assert not Store.indexExists<Text, StoreRecord>(store, "index_unknown");

  switch (Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  )) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };
  switch (Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-2",
    record("Beta", "inactive", "services"),
    ?[("index_status", "inactive"), ("index_category", "services")]
  )) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };
  switch (Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-3",
    record("Gamma", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  )) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };

  let statusSizeInitial = switch (Store.indexSize<Text, StoreRecord>(store, "index_status")) {
    case (#ok size) size;
    case (#err _) { assert false; return };
  };
  assert statusSizeInitial == 2;

  let categorySizeInitial = switch (Store.indexSize<Text, StoreRecord>(store, "index_category")) {
    case (#ok size) size;
    case (#err _) { assert false; return };
  };
  assert categorySizeInitial == 2;

  assert Store.size<Text, StoreRecord>(store) == 3;
  assert Store.exists<Text, StoreRecord>(store, Text.compare, "acct-2");

  let activeKeys = switch (Store.keysBy<Text, StoreRecord>(store, "index_status", "active")) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert activeKeys == ["acct-1", "acct-3"];

  let descendingKeys = switch (Store.keysByOrder<Text, StoreRecord>(store, "index_status", "active", #descending)) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert descendingKeys == ["acct-3", "acct-1"];

  let orderedPage = switch (Store.pageKeysByOrder<Text, StoreRecord>(store, "index_status", "active", #descending, 0, 1)) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert orderedPage == ["acct-3"];

  let ascendingKeys = switch (Store.keysByOrder<Text, StoreRecord>(store, "index_status", "active", #ascending)) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert ascendingKeys == ["acct-1", "acct-3"];

  let hardwareValues = switch (Store.valuesBy<Text, StoreRecord>(store, Text.compare, "index_category", "hardware")) {
    case (#err _) { assert false; return };
    case (#ok vals) { vals };
  };
  assert hardwareValues.size() == 2;

  let countActive = switch (Store.countBy<Text, StoreRecord>(store, "index_status", "active")) {
    case (#err _) { assert false; return };
    case (#ok n) { n };
  };
  assert countActive == 2;

  let firstActive = switch (Store.firstBy<Text, StoreRecord>(store, Text.compare, "index_status", "active")) {
    case (#err _) { assert false; return };
    case (#ok value) { value };
  };
  assert switch (firstActive) { case null false; case (?v) { v.status == "active" } };

  let pagedKeys = switch (Store.pageKeysBy<Text, StoreRecord>(store, "index_status", "active", 1, 1)) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert pagedKeys == ["acct-3"];

  let pagedValues = switch (Store.pageBy<Text, StoreRecord>(store, Text.compare, "index_status", "active", 0, 1)) {
    case (#err _) { assert false; return };
    case (#ok vals) { vals };
  };
  assert pagedValues.size() == 1;

  let insertResult = switch (Store.put<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-4",
    record("Delta", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  )) {
    case (#err _) { assert false; return };
    case (#ok value) { value };
  };
  assert insertResult == null;
  assert Store.size<Text, StoreRecord>(store) == 4;

  let previous = switch (Store.put<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-2",
    record("Beta", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  )) {
    case (#err _) { assert false; return };
    case (#ok value) { value };
  };
  assert switch (previous) { case null false; case (?v) { v.status == "inactive" } };

  switch (Store.update<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-3",
    func current = record(current.name, "inactive", current.category),
    ?[("index_status", "inactive"), ("index_category", "hardware")]
  )) {
    case (#err _) { assert false; return };
    case (#ok updated) { assert updated.status == "inactive" };
  };

  switch (Store.renameKey<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-4",
    "acct-4x",
    record("Delta", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  )) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };
  assert Store.get<Text, StoreRecord>(store, Text.compare, "acct-4") == null;
  assert Store.exists<Text, StoreRecord>(store, Text.compare, "acct-4x");

  switch (Store.remove<Text, StoreRecord>(store, Text.compare, "acct-1")) {
    case (#err _) { assert false; return };
    case (#ok removed) { assert removed.name == "Alpha" };
  };

  let postRemovalKeys = switch (Store.keysBy<Text, StoreRecord>(store, "index_status", "active")) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert Array.indexOf<Text>(postRemovalKeys, Text.equal, "acct-4x") != null;

  type DepositAccount = {
    balance : Nat;
    status : Text;
  };

  let accounts = Store.empty<Text, DepositAccount>("account-store");
  ignore Store.registerIndex<Text, DepositAccount>(accounts, "index_status");

  ignore Store.add<Text, DepositAccount>(
    accounts,
    Text.compare,
    "acct-low",
    { balance = 100; status = "active" },
    ?[("index_status", "active")]
  );
  ignore Store.add<Text, DepositAccount>(
    accounts,
    Text.compare,
    "acct-mid",
    { balance = 500; status = "active" },
    ?[("index_status", "active")]
  );
  ignore Store.add<Text, DepositAccount>(
    accounts,
    Text.compare,
    "acct-high",
    { balance = 900; status = "active" },
    ?[("index_status", "active")]
  );

  let balanceDescending = switch (Store.keysByValue<Text, DepositAccount, Nat>(
    accounts,
    Text.compare,
    "index_status",
    "active",
    #descending,
    func (_, acc) = acc.balance,
    Nat.compare
  )) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert balanceDescending == ["acct-high", "acct-mid", "acct-low"];

  let balanceAscendingPage = switch (Store.pageKeysByValue<Text, DepositAccount, Nat>(
    accounts,
    Text.compare,
    "index_status",
    "active",
    #ascending,
    0,
    2,
    func (_, acc) = acc.balance,
    Nat.compare
  )) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert balanceAscendingPage == ["acct-low", "acct-mid"];

  let balanceAscending = switch (Store.keysByValue<Text, DepositAccount, Nat>(
    accounts,
    Text.compare,
    "index_status",
    "active",
    #ascending,
    func (_, acc) = acc.balance,
    Nat.compare
  )) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert balanceAscending == ["acct-low", "acct-mid", "acct-high"];

  switch (Store.clearIndex<Text, StoreRecord>(store, "index_category")) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };

  let emptyAfterClear = switch (Store.valuesBy<Text, StoreRecord>(store, Text.compare, "index_category", "hardware")) {
    case (#err _) { assert false; return };
    case (#ok vals) { vals };
  };
  assert emptyAfterClear.size() == 0;
  assert switch (Store.indexSize<Text, StoreRecord>(store, "index_category")) {
    case (#ok size) size == 0;
    case (#err _) { false };
  };

  Store.clear<Text, StoreRecord>(store);
  assert Store.size<Text, StoreRecord>(store) == 0;
});

test("Store index utilities", func () {
  let store = Store.empty<Text, StoreRecord>("utility-store");

  ignore Store.registerIndex<Text, StoreRecord>(store, "index_status");
  ignore Store.registerIndex<Text, StoreRecord>(store, "index_category");

  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  );
  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-2",
    record("Beta", "inactive", "services"),
    ?[("index_status", "inactive"), ("index_category", "services")]
  );

  switch (Store.registerIndex<Text, StoreRecord>(store, "index_namePrefix")) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };

  switch (Store.rebuildIndex<Text, StoreRecord>(store, Text.compare, "index_namePrefix", func value = value.name # "-prefix")) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };

  let names = Store.indexNames<Text, StoreRecord>(store);
  assert Array.indexOf<Store.IndexName>(names, Text.equal, "index_namePrefix") != null;

  let prefixKeys = switch (Store.indexKeys<Text, StoreRecord>(store, "index_namePrefix")) {
    case (#err _) { assert false; return };
    case (#ok keys) { keys };
  };
  assert prefixKeys.size() == 2;

  switch (Store.reindexRecord<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-2",
    [("index_namePrefix", "Beta-prefix")],
    [("index_namePrefix", "Beta-new")]
  )) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };

  switch (Store.verifyIndex<Text, StoreRecord>(store, Text.compare, "index_namePrefix", func value = value.name # "-prefix")) {
    case (#ok _) { assert false; return };
    case (#err (#inconsistent mismatches)) { assert mismatches > 0 };
    case (#err (#invalidIndex)) { assert false; return };
  };

  switch (Store.rebuildIndex<Text, StoreRecord>(store, Text.compare, "index_namePrefix", func value = value.name # "-prefix")) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };

  switch (Store.verifyIndex<Text, StoreRecord>(store, Text.compare, "index_namePrefix", func value = value.name # "-prefix")) {
    case (#ok _) {};
    case (#err (#inconsistent _)) { assert false; return };
    case (#err (#invalidIndex)) { assert false; return };
  };

  let filtered = Store.filter<Text, StoreRecord>(store, func (_, value) = value.status == "active");
  assert filtered.size() == 1;

  let found = Store.find<Text, StoreRecord>(store, func (_, value) = value.status == "inactive");
  assert switch (found) { case null false; case (?v) { v.name == "Beta" } };

  assert Store.any<Text, StoreRecord>(store, func (_, value) = value.category == "services");

  let mapped = Store.mapValues<Text, StoreRecord, Text>(store, func (_, value) = value.name);
  assert Array.indexOf<Text>(mapped, Text.equal, "Alpha") != null;

  switch (Store.clearIndex<Text, StoreRecord>(store, "index_namePrefix")) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };

  switch (Store.unregisterIndex<Text, StoreRecord>(store, "index_namePrefix")) {
    case (#err _) { assert false; return };
    case (#ok _) {};
  };
});

test("Store handles error cases", func () {
  let store = Store.empty<Text, StoreRecord>("errors");

  ignore Store.registerIndex<Text, StoreRecord>(store, "index_status");
  ignore Store.registerIndex<Text, StoreRecord>(store, "index_category");

  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  );
  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-2",
    record("Beta", "inactive", "services"),
    ?[("index_status", "inactive"), ("index_category", "services")]
  );

  switch (Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Duplicate", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  )) {
    case (#err (#keyExists)) {};
    case (_) { assert false; return };
  };

  switch (Store.add<Text, StoreRecord>(store, Text.compare, "acct-3", record("Missing", "active", "hardware"), null)) {
    case (#err (#indexMismatch)) {};
    case (_) { assert false; return };
  };

  switch (Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-4",
    record("Invalid", "active", "hardware"),
    ?[("unknown", "set"), ("index_status", "active")]
  )) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  assert not Store.indexExists<Text, StoreRecord>(store, "index_unknown");
  switch (Store.indexSize<Text, StoreRecord>(store, "index_unknown")) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.put<Text, StoreRecord>(store, Text.compare, "acct-5", record("PutMissing", "active", "hardware"), null)) {
    case (#err (#indexMismatch)) {};
    case (_) { assert false; return };
  };

  switch (Store.put<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-5",
    record("PutInvalid", "active", "hardware"),
    ?[("index_status", "active"), ("bogus", "set")]
  )) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.update<Text, StoreRecord>(store, Text.compare, "unknown", func r = r, null)) {
    case (#err (#notFound)) {};
    case (_) { assert false; return };
  };

  switch (Store.update<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    func r = { r with status = "inactive" },
    ?[("bogus", "set")]
  )) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.renameKey<Text, StoreRecord>(store, Text.compare, "missing", "acct-new", record("Alpha", "active", "hardware"), null)) {
    case (#err (#notFound)) {};
    case (_) { assert false; return };
  };

  switch (Store.renameKey<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    "acct-2",
    record("Alpha", "active", "hardware"),
    null
  )) {
    case (#err (#keyExists)) {};
    case (_) { assert false; return };
  };

  switch (Store.remove<Text, StoreRecord>(store, Text.compare, "missing")) {
    case (#err (#notFound)) {};
    case (_) { assert false; return };
  };

  switch (Store.keysBy<Text, StoreRecord>(store, "bogus", "value")) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.valuesBy<Text, StoreRecord>(store, Text.compare, "bogus", "value")) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.pageKeysBy<Text, StoreRecord>(store, "bogus", "value", 0, 10)) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.pageBy<Text, StoreRecord>(store, Text.compare, "bogus", "value", 0, 10)) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.reindexRecord<Text, StoreRecord>(
    store,
    Text.compare,
    "missing",
    [("index_status", "active")],
    [("index_status", "inactive")]
  )) {
    case (#err (#notFound)) {};
    case (_) { assert false; return };
  };

  switch (Store.reindexRecord<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-2",
    [("index_status", "inactive")],
    [("bogus", "set")]
  )) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.rebuildIndex<Text, StoreRecord>(store, Text.compare, "bogus", func v = v.status)) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.verifyIndex<Text, StoreRecord>(store, Text.compare, "bogus", func v = v.status)) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.registerIndex<Text, StoreRecord>(store, "index_status")) {
    case (#err (#indexExists)) {};
    case (_) { assert false; return };
  };

  switch (Store.unregisterIndex<Text, StoreRecord>(store, "missing")) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };
});
