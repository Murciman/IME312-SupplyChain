-- Drop in reverse FK order so constraints don't block drops
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS shipping;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS departments;

-- ─── Reference / lookup tables ──────────────────────────────────────────────

CREATE TABLE categories(
    "id"            INTEGER PRIMARY KEY,
    "category_name" TEXT    NOT NULL
);

-- Market is NOT stored here. A department (e.g. "Apparel") can operate in
-- multiple markets, so market belongs on the order, not the department.
CREATE TABLE departments(
    "id"              INTEGER PRIMARY KEY,
    "department_name" TEXT    NOT NULL
);

-- ─── Entity tables ───────────────────────────────────────────────────────────

CREATE TABLE customers(
    "id"      INTEGER PRIMARY KEY,
    "segment" TEXT NOT NULL,
    "city"    TEXT NOT NULL,
    "state"   TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "market"  TEXT NOT NULL
);

CREATE TABLE products(
    "id"            INTEGER PRIMARY KEY,
    "category_id"   INTEGER NOT NULL,
    "department_id" INTEGER NOT NULL,
    "product_name"  TEXT    NOT NULL,
    "product_price" REAL    NOT NULL CHECK(product_price >= 0),
    FOREIGN KEY ("category_id")   REFERENCES categories("id"),
    FOREIGN KEY ("department_id") REFERENCES departments("id")
);

-- ─── Transaction tables ───────────────────────────────────────────────────────

-- Order-level information only. Item details live in order_items.
-- profit_per_order has NO check constraint — negative profit (a loss) is
-- real business data and must not be discarded.
CREATE TABLE orders(
    "id"               INTEGER PRIMARY KEY,
    "customer_id"      INTEGER NOT NULL,
    "order_date"       TEXT    NOT NULL,
    "order_status"     TEXT    NOT NULL,
    "order_region"     TEXT,
    "order_country"    TEXT,
    "market"           TEXT,
    "profit_per_order" REAL,
    FOREIGN KEY ("customer_id") REFERENCES customers("id")
);

-- Each row is one line item inside an order.
-- Keeps product, quantity, pricing, and per-item profit separate from the order.
CREATE TABLE order_items(
    "id"               INTEGER PRIMARY KEY,
    "order_id"         INTEGER NOT NULL,
    "product_id"       INTEGER NOT NULL,
    "quantity"         INTEGER NOT NULL CHECK(quantity > 0),
    "item_price"       REAL,
    "discount"         REAL,
    "discount_rate"    REAL,
    "sales"            REAL,
    "item_profit"      REAL,
    "profit_ratio"     REAL,
    "order_item_total" REAL,
    FOREIGN KEY ("order_id")   REFERENCES orders("id"),
    FOREIGN KEY ("product_id") REFERENCES products("id")
);

-- Shipping is recorded at the order level (one row per order).
-- ship_date is kept so delivery lead-time can be computed later.
CREATE TABLE shipping(
    "id"                 INTEGER PRIMARY KEY AUTOINCREMENT,
    "order_id"           INTEGER NOT NULL UNIQUE,
    "shipping_mode"      TEXT    NOT NULL,
    "ship_date"          TEXT,
    "days_scheduled"     REAL,
    "days_actual"        REAL,
    "delivery_status"    TEXT    NOT NULL,
    "late_delivery_risk" INTEGER NOT NULL,
    FOREIGN KEY ("order_id") REFERENCES orders("id")
);
