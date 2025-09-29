import { test } "mo:test";
import Store "../src/";
import Text "mo:core/Text";
import Iter "mo:core/Iter";
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

func keysToArray(iter : Iter.Iter<Text>) : [Text] {
  Iter.toArray(iter);
};

test("Key ordering by status", func () {
  let store = Store.empty<Text, StoreRecord>("ordering-store");
  ignore Store.registerIndex<Text, StoreRecord>(store, "index_status");

  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-1",
    record("Alpha", "active", "hardware"),
    ?[("index_status", "active")]
  );
  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-3",
    record("Gamma", "active", "hardware"),
    ?[("index_status", "active")]
  );
  ignore Store.add<Text, StoreRecord>(
    store,
    Text.compare,
    "acct-2",
    record("Beta", "inactive", "services"),
    ?[("index_status", "inactive")]
  );

  let ascending = switch (Store.keysByOrder<Text, StoreRecord>(store, "index_status", "active", #ascending)) {
    case (#ok iter) keysToArray(iter);
    case (#err _) { assert false; return };
  };
  assert ascending == ["acct-1", "acct-3"];

  let descending = switch (Store.keysByOrder<Text, StoreRecord>(store, "index_status", "active", #descending)) {
    case (#ok iter) keysToArray(iter);
    case (#err _) { assert false; return };
  };
  assert descending == ["acct-3", "acct-1"];

  let page = switch (Store.pageKeysByOrder<Text, StoreRecord>(store, "index_status", "active", #descending, 0, 1)) {
    case (#ok iter) keysToArray(iter);
    case (#err _) { assert false; return };
  };
  assert page == ["acct-3"];
});

type DepositAccount = {
  balance : Nat;
  status : Text;
};

func makeAccounts() : Store.Store<Text, DepositAccount> {
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
  accounts;
};

func balances(values : [DepositAccount]) : [Nat] {
  Array.map<DepositAccount, Nat>(values, func acc = acc.balance);
};

test("Value ordering by projection", func () {
  let accounts = makeAccounts();

  let descKeys = switch (Store.keysByValue<Text, DepositAccount, Nat>(
    accounts,
    Text.compare,
    "index_status",
    "active",
    #descending,
    func (_, acc) = acc.balance,
    Nat.compare
  )) {
    case (#ok iter) keysToArray(iter);
    case (#err _) { assert false; return };
  };
  assert descKeys == ["acct-high", "acct-mid", "acct-low"];

  let ascKeyPage = switch (Store.pageKeysByValue<Text, DepositAccount, Nat>(
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
    case (#ok iter) keysToArray(iter);
    case (#err _) { assert false; return };
  };
  assert ascKeyPage == ["acct-low", "acct-mid"];

  let descValues = switch (Store.valuesByOrder<Text, DepositAccount, Nat>(
    accounts,
    Text.compare,
    "index_status",
    "active",
    #descending,
    func acc = acc.balance,
    Nat.compare
  )) {
    case (#ok iter) Iter.toArray(iter);
    case (#err _) { assert false; return };
  };
  assert balances(descValues) == [900, 500, 100];
});
