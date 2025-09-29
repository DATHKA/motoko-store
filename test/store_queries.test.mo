import { test } "mo:test";
import Store "../src/";
import Text "mo:core/Text";
import Iter "mo:core/Iter";
import Array "mo:core/Array";

type StoreRecord = {
  name : Text;
  status : Text;
  category : Text;
};

func record(name : Text, status : Text, category : Text) : StoreRecord {
  { name; status; category };
};

func prepareStore() : Store.Store<Text, StoreRecord> {
  let store = Store.empty<Text, StoreRecord>("query-store");
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
  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-3",
    record("Gamma", "active", "hardware"),
    ?[("index_status", "active"), ("index_category", "hardware")]
  );
  store;
};

func toArray<T>(iter : Iter.Iter<T>) : [T] {
  Iter.toArray(iter);
};

test("Keys values and counts", func () {
  let store = prepareStore();

  assert Store.size<Text, StoreRecord>(store) == 3;

  assert toArray<Text>(Store.keys<Text, StoreRecord>(store)) == ["acct-1", "acct-2", "acct-3"];

  let allValues = toArray<StoreRecord>(Store.values<Text, StoreRecord>(store));
  assert allValues.size() == 3;
  assert allValues[0].name == "Alpha";
  assert allValues[1].name == "Beta";

  let activeKeys = switch (Store.keysBy<Text, StoreRecord>(store, "index_status", "active")) {
    case (#ok iter) toArray<Text>(iter);
    case (#err _) { assert false; return };
  };
  assert activeKeys == ["acct-1", "acct-3"];

  let activeCount = switch (Store.indexSizeBy<Text, StoreRecord>(store, "index_status", "active")) {
    case (#ok count) count;
    case (#err _) { assert false; return };
  };
  assert activeCount == 2;

  let statusKeySets = switch (Store.indexKeys<Text, StoreRecord>(store, "index_status")) {
    case (#ok names) names;
    case (#err _) { assert false; return };
  };
  assert statusKeySets == ["active", "inactive"];
});

test("Pagination helpers", func () {
  let store = prepareStore();

  let keyPage = switch (Store.pageKeysBy<Text, StoreRecord>(store, "index_status", "active", 1, 1)) {
    case (#ok iter) toArray<Text>(iter);
    case (#err _) { assert false; return };
  };
  assert keyPage == ["acct-3"];

  let valuePage = switch (Store.pageBy<Text, StoreRecord>(store, Text.compare, "index_status", "active", 0, 1)) {
    case (#ok iter) toArray<StoreRecord>(iter);
    case (#err _) { assert false; return };
  };
  assert valuePage.size() == 1 and valuePage[0].name == "Alpha";

  let orderedValues = switch (Store.pageValuesByOrder<Text, StoreRecord, Text>(
    store,
    Text.compare,
    "index_status",
    "active",
    #descending,
    0,
    1,
    func value = value.name,
    Text.compare
  )) {
    case (#ok iter) toArray<StoreRecord>(iter);
    case (#err _) { assert false; return };
  };
  assert orderedValues.size() == 1 and orderedValues[0].name == "Gamma";
});

test("Filter find any and map values", func () {
  let store = prepareStore();

  let filtered = toArray<StoreRecord>(Store.filter<Text, StoreRecord>(store, func (_, value) = value.status == "active"));
  assert Array.map<StoreRecord, Text>(filtered, func v = v.name) == ["Alpha", "Gamma"];

  let found = Store.find<Text, StoreRecord>(store, func (_, value) = value.category == "services");
  assert switch (found) {
    case (?value) value.name == "Beta";
    case null false;
  };

  assert Store.any<Text, StoreRecord>(store, func (_, value) = value.category == "hardware");

  let names = toArray<Text>(Store.mapValues<Text, StoreRecord, Text>(store, func (_, value) = value.name));
  assert names == ["Alpha", "Beta", "Gamma"];
});

test("Error to text covers all cases", func () {
  assert Store.errorToText(#keyExists) == "Key already exists.";
  assert Store.errorToText(#indexMismatch) == "Index mismatch.";
  assert Store.errorToText(#invalidIndex) == "Invalid index.";
  assert Store.errorToText(#notFound) == "Not found";
  assert Store.errorToText(#indexExists) == "Index exists";
});
