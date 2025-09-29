import { test } "mo:test";
import Store "../src/";
import Text "mo:core/Text";

type StoreRecord = {
  name : Text;
  status : Text;
  category : Text;
};

func record(name : Text, status : Text, category : Text) : StoreRecord {
  { name; status; category };
};

test("Error scenarios", func () {
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

  switch (Store.replace<Text, StoreRecord>(
    store,
    Text.compare,
    "missing",
    record("Missing", "active", "hardware"),
    null
  )) {
    case (#err (#notFound)) {};
    case (_) { assert false; return };
  };

  switch (Store.replace<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("bogus", "set")]
  )) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };

  switch (Store.update<Text, StoreRecord>(store, Text.compare, "unknown", func r = r, null)) {
    case (#err (#notFound)) {};
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

  switch (Store.delete<Text, StoreRecord>(store, Text.compare, "missing")) {
    case (#err (#notFound)) {};
    case (_) { assert false; return };
  };

  Store.remove<Text, StoreRecord>(store, Text.compare, "acct-2");
  assert not Store.containsKey<Text, StoreRecord>(store, Text.compare, "acct-2");

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
});

test("Reindex and index errors", func () {
  let store = Store.empty<Text, StoreRecord>("errors-index");
  ignore Store.registerIndex<Text, StoreRecord>(store, "index_status");

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

  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("index_status", "active")]
  );

  switch (Store.reindexRecord<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    [("index_status", "active")],
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

  switch (Store.indexSizeBy<Text, StoreRecord>(store, "bogus", "value")) {
    case (#err (#invalidIndex)) {};
    case (_) { assert false; return };
  };
});
