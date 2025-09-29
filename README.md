# store

`store` is a lightweight key/value data structure for Motoko projects that need
mutable records together with secondary indexes. Each index tracks a specific
set key (for example, `index_status` or `index_category`) and can be queried later to
retrieve the matching records. The library is designed for stable storage and
works with the core Motoko `Map` / `Set` modules introduced in `mo:core` 1.0.0.

## Installation

Add the package to your project with [MOPS](https://mops.one):

```bash
mops add store
```

Then import it in your Motoko canister/code:

```motoko
import Store "mo:store";
```

## Usage

The example below registers two indexes (`index_status` and `index_category`), stores a few
records, and performs lookups via the `index_status` index. All operations that touch
keys require the comparator to be supplied—here we use `Text.compare`.

```motoko
import Store "mo:store";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Nat "mo:core/Nat";
import Iter "mo:core/Iter";
import Debug "mo:core/Debug";

type Merchant = {
  name : Text;
  status : Text;
  category : Text;
};

func main() : async () {
  // Initialise an empty store and register indexes for status and category.
  let store = Store.empty<Text, Merchant>("merchant-store");

  ignore Store.registerIndex<Text, Merchant>(store, "index_status");
  ignore Store.registerIndex<Text, Merchant>(store, "index_category");

  // Insert a couple of merchants and attach their index metadata.
  ignore Store.add<Text, Merchant>(
    store,
    Text.compare,
    "acct-1",
    { name = "Alpha"; status = "active"; category = "hardware" },
    ?[("index_status", "active"), ("index_category", "hardware")]
  );

  ignore Store.add<Text, Merchant>(
    store,
    Text.compare,
    "acct-2",
    { name = "Beta"; status = "inactive"; category = "services" },
    ?[("index_status", "inactive"), ("index_category", "services")]
  );

  ignore Store.add<Text, Merchant>(
    store,
    Text.compare,
    "acct-3",
    { name = "Gamma"; status = "active"; category = "hardware" },
    ?[("index_status", "active"), ("index_category", "hardware")]
  );

  ignore Store.add<Text, Merchant>(
    store,
    Text.compare,
    "acct-4",
    { name = "Delta"; status = "inactive"; category = "services" },
    ?[("index_status", "inactive"), ("index_category", "services")]
  );

  // Pull all active merchants via the index.
  let activeMerchants = switch (Store.valuesBy<Text, Merchant>(store, Text.compare, "index_status", "active")) {
    case (#ok iter) Iter.toArray(iter);
    case (#err _) [];
  };

  // Fetch the first inactive merchant (ordered by key).
  let firstInactive = switch (Store.firstBy<Text, Merchant>(store, Text.compare, "index_status", "inactive")) {
    case (#ok (?merchant)) ?merchant;
    case _ null;
  };

  // Inspect key ordering for the active status bucket.
  let descendingKeys = switch (Store.keysByOrder<Text, Merchant>(store, "index_status", "active", #descending)) {
    case (#ok iter) Iter.toArray(iter);
    case (#err _) [];
  };

  let ascendingKeys = switch (Store.keysByOrder<Text, Merchant>(store, "index_status", "active", #ascending)) {
    case (#ok iter) Iter.toArray(iter);
    case (#err _) [];
  };

  // Demonstrate sorting by value projections using deposit accounts.
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

  let byBalanceDescending = switch (Store.keysByValue<Text, DepositAccount, Nat>(
    accounts,
    Text.compare,
    "index_status",
    "active",
    #descending,
    func (_, acc) = acc.balance,
    Nat.compare
  )) {
    case (#ok iter) Iter.toArray(iter);
    case (#err _) [];
  };

  // Page through accounts in ascending order by balance.
  let byBalanceAscendingPage = switch (Store.pageKeysByValue<Text, DepositAccount, Nat>(
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
    case (#ok iter) Iter.toArray(iter);
    case (#err _) [];
  };

  func joinKeys(keys : [Text]) : Text {
    Array.foldLeft<Text, Text>(keys, "", func (acc, key) =
      if (acc == "") key else acc # " | " # key
    );
  };

  func showMerchants(title : Text, merchants : [Merchant]) {
    Debug.print(title # ": " # Array.foldLeft<Merchant, Text>(merchants, "", func (acc, m) = acc # m.name # " "));
  };

  // Log the results to illustrate the operations.
  showMerchants("Active merchants", activeMerchants);
  Debug.print("First inactive: " # (switch (firstInactive) { case null "none"; case (?m) m.name }));
  Debug.print("Ascending active keys: " # joinKeys(ascendingKeys));
  Debug.print("Descending active keys: " # joinKeys(descendingKeys));
  Debug.print("By balance (descending): " # joinKeys(byBalanceDescending));
  Debug.print("Balance page (page 1, 2 items, ascending): " # joinKeys(byBalanceAscendingPage));
}
```

See `src/lib.mo` for the full API, including helpers for updates, renaming
keys, rebuilding indexes, advanced sorting utilities, and validating index consistency.
