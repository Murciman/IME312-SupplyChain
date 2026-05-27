DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS shipping;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS departments;

CREATE TABLE customers(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "segment" TEXT NOT NULL,
    "city" TEXT NOT NULL,
    "state" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "market" TEXT NOT NULL
);

CREATE TABLE orders(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "customer_id" INTEGER NOT NULL,
    "product_id" INTEGER NOT NULL,
    "order_date" NUMERIC NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "quantity" INTEGER,
    "profit_per_order" FLOAT NOT NULL,
    "order_status" TEXT NOT NULL,
    FOREIGN KEY ("customer_id") REFERENCES customer("id"),
    FOREIGN KEY ("product_id") REFERENCES products("id")
);

CREATE TABLE products(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "category_id" INTEGER NOT NULL,
    "department_id" INTEGER NOT NULL,
    "product_name" TEXT NOT NULL,
    "product_price", FLOAT NOT NULL,
    FOREIGN KEY ("category_id") REFERENCES categories("id"),
    FOREIGN KEY ("department_id") REFERENCES departments("id")
);

CREATE TABLE shipping(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "order_id" INTEGER NOT NULL,
    "shipping_mode" TEXT NOT NULL,
    "days_scheduled" INTEGER NOT NULL,
    "days_actual" INTEGER NOT NULL,
    "delivery_status" TEXT NOT NULL,
    "late_delivery_risk" INTEGER NOT NULL,

    FOREIGN KEY ("order_id") REFERENCES orders("id")
);

CREATE TABLE categories(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "category_name" TEXT NOT NULL
);

CREATE TABLE departments(
    "id" INTEGER PRIMARY KEY AUTOINCREMENT,
    "department_name" TEXT NOT NULL,
    "market" TEXT NOT NULL
);