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

type Merchant = {
  name : Text;
  status : Text;
  category : Text;
};

func main() : async () {
  let store = Store.empty<Text, Merchant>("merchant-store");

  ignore Store.registerIndex<Text, Merchant>(store, "index_status");
  ignore Store.registerIndex<Text, Merchant>(store, "index_category");

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

  let activeMerchants = switch (Store.valuesBy<Text, Merchant>(store, Text.compare, "index_status", "active")) {
    case (#ok merchants) merchants;
    case (#err _) [];
  };

  let firstInactive = switch (Store.firstBy<Text, Merchant>(store, Text.compare, "index_status", "inactive")) {
    case (#ok (?merchant)) ?merchant;
    case _ null;
  };

  Debug.print("Active merchants: " # debug_show(activeMerchants));
  Debug.print("First inactive: " # debug_show(firstInactive));
}
```

See `src/lib.mo` for the full API, including helpers for updates, renaming
keys, rebuilding indexes, and validating index consistency.
