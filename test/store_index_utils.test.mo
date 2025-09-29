import { test } "mo:test";
import Store "../src/";
import Text "mo:core/Text";
import Array "mo:core/Array";

type StoreRecord = {
  name : Text;
  status : Text;
};

func record(name : Text, status : Text) : StoreRecord {
  { name; status };
};

test("Register rebuild verify index", func () {
  let store = Store.empty<Text, StoreRecord>("index-store");

  ignore Store.add<Text, StoreRecord>(store, Text.compare, "acct-1", record("Alpha", "active"), null);
  ignore Store.add<Text, StoreRecord>(store, Text.compare, "acct-2", record("Beta", "inactive"), null);

  ignore Store.registerIndex<Text, StoreRecord>(store, "index_status");

  switch (Store.rebuildIndex<Text, StoreRecord>(store, Text.compare, "index_status", func value = value.status)) {
    case (#ok _) {};
    case (#err _) { assert false; return };
  };

  switch (Store.verifyIndex<Text, StoreRecord>(store, Text.compare, "index_status", func value = value.status)) {
    case (#ok _) {};
    case (#err _) { assert false; return };
  };

  let names = Store.indexNames<Text, StoreRecord>(store);
  assert Array.indexOf<Text>(names, Text.equal, "index_status") != null;

  switch (Store.unregisterIndex<Text, StoreRecord>(store, "index_status")) {
    case (#ok _) {};
    case (#err _) { assert false; return };
  };
  assert not Store.indexExists<Text, StoreRecord>(store, "index_status");
});
