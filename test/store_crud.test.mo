import { test } "mo:test";
import Store "../src/";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";

type StoreRecord = {
  name : Text;
  status : Text;
  category : Text;
};

func record(name : Text, status : Text, category : Text) : StoreRecord {
  { name; status; category };
};

func eqRecord(a : StoreRecord, b : StoreRecord) : Bool {
  a.name == b.name and a.status == b.status and a.category == b.category;
};

func makeStore() : Store.Store<Text, StoreRecord> {
  let store = Store.empty<Text, StoreRecord>("merchant-store");
  ignore Store.registerIndex<Text, StoreRecord>(store, "index_status");
  ignore Store.registerIndex<Text, StoreRecord>(store, "index_category");
  store;
};

func valuesToArray(iter : Iter.Iter<StoreRecord>) : [StoreRecord] {
  Iter.toArray(iter);
};

func keysToArray(iter : Iter.Iter<Text>) : [Text] {
  Iter.toArray(iter);
};

test("Store initialises empty", func () {
  let store = makeStore();

  assert Store.size<Text, StoreRecord>(store) == 0;
  assert not Store.containsKey<Text, StoreRecord>(store, Text.compare, "acct-1");
  assert Store.indexExists<Text, StoreRecord>(store, "index_status");
  assert Store.indexExists<Text, StoreRecord>(store, "index_category");
  assert not Store.indexExists<Text, StoreRecord>(store, "missing_index");
  assert switch (Store.indexSize<Text, StoreRecord>(store, "index_status")) {
    case (#ok size) size == 0;
    case (#err _) false;
  };
});

test("Store add and retrieve", func () {
  let store = makeStore();

  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  );

  assert Store.containsKey<Text, StoreRecord>(store, Text.compare, "acct-1");
  assert switch (Store.get<Text, StoreRecord>(store, Text.compare, "acct-1")) {
    case (?value) eqRecord(value, record("Alpha", "active", "hardware"));
    case null false;
  };

  assert switch (Store.indexSize<Text, StoreRecord>(store, "index_status")) {
    case (#ok size) size == 1;
    case (#err _) false;
  };
  assert switch (Store.indexSizeBy<Text, StoreRecord>(store, "index_status", "active")) {
    case (#ok count) count == 1;
    case (#err _) false;
  };

  let activeValues = switch (Store.valuesBy<Text, StoreRecord>(store, Text.compare, "index_status", "active")) {
    case (#ok iter) valuesToArray(iter);
    case (#err _) { assert false; return };
  };
  assert activeValues.size() == 1;
});

test("Store put replace delete remove", func () {
  let store = makeStore();

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
    record("Beta", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  );

  switch (Store.put<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "inactive", "hardware"),
    ?[("index_status", "inactive"), ("index_category", "hardware")]
  )) {
    case (#ok prev) { assert switch (prev) { case (?value) value.status == "active"; case null false } };
    case (#err _) { assert false; return };
  };

  switch (Store.replace<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  )) {
    case (#ok value) { assert value.status == "active" };
    case (#err _) { assert false; return };
  };

  let activeEntries = switch (Store.entriesBy<Text, StoreRecord>(store, Text.compare, "index_status", "active")) {
    case (#ok iter) Iter.toArray(iter);
    case (#err _) { assert false; return };
  };
  assert activeEntries.size() == 2;
  assert activeEntries[0].0 == "acct-1";
  assert eqRecord(activeEntries[0].1, record("Alpha", "active", "hardware"));

  switch (Store.delete<Text, StoreRecord>(store, Text.compare, "acct-1")) {
    case (#ok removed) { assert removed.name == "Alpha" };
    case (#err _) { assert false; return };
  };
  assert not Store.containsKey<Text, StoreRecord>(store, Text.compare, "acct-1");

  Store.remove<Text, StoreRecord>(store, Text.compare, "acct-2");
  assert not Store.containsKey<Text, StoreRecord>(store, Text.compare, "acct-2");
});

