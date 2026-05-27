-- ─── 1. Raw staging table ────────────────────────────────────────────────────
DROP TABLE IF EXISTS raw_import;
CREATE TABLE raw_import(
  "Type"                          TEXT,
  "Days for shipping (real)"      TEXT,
  "Days for shipment (scheduled)" TEXT,
  "Benefit per order"             TEXT,
  "Sales per customer"            TEXT,
  "Delivery Status"               TEXT,
  "Late_delivery_risk"            TEXT,
  "Category Id"                   TEXT,
  "Category Name"                 TEXT,
  "Customer City"                 TEXT,
  "Customer Country"              TEXT,
  "Customer Email"                TEXT,
  "Customer Fname"                TEXT,
  "Customer Id"                   TEXT,
  "Customer Lname"                TEXT,
  "Customer Password"             TEXT,
  "Customer Segment"              TEXT,
  "Customer State"                TEXT,
  "Customer Street"               TEXT,
  "Customer Zipcode"              TEXT,
  "Department Id"                 TEXT,
  "Department Name"               TEXT,
  "Latitude"                      TEXT,
  "Longitude"                     TEXT,
  "Market"                        TEXT,
  "Order City"                    TEXT,
  "Order Country"                 TEXT,
  "Order Customer Id"             TEXT,
  "order date (DateOrders)"       TEXT,
  "Order Id"                      TEXT,
  "Order Item Cardprod Id"        TEXT,
  "Order Item Discount"           TEXT,
  "Order Item Discount Rate"      TEXT,
  "Order Item Id"                 TEXT,
  "Order Item Product Price"      TEXT,
  "Order Item Profit Ratio"       TEXT,
  "Order Item Quantity"           TEXT,
  "Sales"                         TEXT,
  "Order Item Total"              TEXT,
  "Order Profit Per Order"        TEXT,
  "Order Region"                  TEXT,
  "Order State"                   TEXT,
  "Order Status"                  TEXT,
  "Order Zipcode"                 TEXT,
  "Product Card Id"               TEXT,
  "Product Category Id"           TEXT,
  "Product Description"           TEXT,
  "Product Image"                 TEXT,
  "Product Name"                  TEXT,
  "Product Price"                 TEXT,
  "Product Status"                TEXT,
  "shipping date (DateOrders)"    TEXT,
  "Shipping Mode"                 TEXT
);

.mode csv
.import DataCoSupplyChainDataset.csv raw_import

-- Remove the header row that .import may have kept
DELETE FROM raw_import
WHERE "Type" = 'Type' AND "Order Id" = 'Order Id';

-- ─── 2. Categories ───────────────────────────────────────────────────────────
-- DISTINCT removes duplicate (id, name) pairs before insert.
INSERT INTO categories (id, category_name)
SELECT DISTINCT
  CAST("Category Id" AS INTEGER),
  "Category Name"
FROM raw_import
WHERE "Category Id"   IS NOT NULL AND "Category Id"   <> ''
  AND "Category Name" IS NOT NULL AND "Category Name" <> '';

-- ─── 3. Departments ──────────────────────────────────────────────────────────
-- Market is intentionally excluded: a department (e.g. "Apparel") spans many
-- markets, so storing one market per department would be misleading.
INSERT INTO departments (id, department_name)
SELECT
  CAST("Department Id" AS INTEGER),
  MIN("Department Name")
FROM raw_import
WHERE "Department Id"   IS NOT NULL AND "Department Id"   <> ''
  AND "Department Name" IS NOT NULL AND "Department Name" <> ''
GROUP BY CAST("Department Id" AS INTEGER);

-- ─── 4. Customers ────────────────────────────────────────────────────────────
-- MIN() is acceptable here only because a given Customer Id should have one
-- consistent city/state/country/segment/market in this dataset.
INSERT INTO customers (id, segment, city, state, country, market)
SELECT
  CAST("Customer Id" AS INTEGER),
  MIN("Customer Segment"),
  MIN("Customer City"),
  MIN("Customer State"),
  MIN("Customer Country"),
  MIN("Market")
FROM raw_import
WHERE "Customer Id"      IS NOT NULL AND "Customer Id"      <> ''
  AND "Customer Segment" IS NOT NULL AND "Customer Segment" <> ''
  AND "Customer City"    IS NOT NULL AND "Customer City"    <> ''
  AND "Customer State"   IS NOT NULL AND "Customer State"   <> ''
  AND "Customer Country" IS NOT NULL AND "Customer Country" <> ''
  AND "Market"           IS NOT NULL AND "Market"           <> ''
GROUP BY CAST("Customer Id" AS INTEGER);

-- ─── 5. Products ─────────────────────────────────────────────────────────────
INSERT INTO products (id, category_id, department_id, product_name, product_price)
SELECT
  CAST("Product Card Id" AS INTEGER),
  MIN(CAST("Product Category Id" AS INTEGER)),
  MIN(CAST("Department Id" AS INTEGER)),
  MIN("Product Name"),
  MIN(CAST("Product Price" AS REAL))
FROM raw_import
WHERE "Product Card Id"    IS NOT NULL AND "Product Card Id"    <> ''
  AND "Product Category Id" IS NOT NULL AND "Product Category Id" <> ''
  AND "Department Id"       IS NOT NULL AND "Department Id"       <> ''
  AND "Product Name"        IS NOT NULL AND "Product Name"        <> ''
  AND "Product Price"       IS NOT NULL AND "Product Price"       <> ''
  AND CAST("Product Price" AS REAL) >= 0
GROUP BY CAST("Product Card Id" AS INTEGER);

-- ─── 6. Orders (order-level only) ────────────────────────────────────────────
-- Each row here is one unique order. Product/quantity/item-profit details go
-- into order_items below.
-- profit_per_order uses MIN() because the raw CSV repeats the same order-level
-- profit on every item row for that order — MIN picks one copy, not a sum.
-- NEGATIVE profits are kept: a loss is real business information.
INSERT INTO orders (id, customer_id, order_date, order_status,
                    order_region, order_country, market, profit_per_order)
SELECT
  CAST("Order Id" AS INTEGER),
  MIN(CAST("Order Customer Id" AS INTEGER)),
  MIN("order date (DateOrders)"),
  MIN("Order Status"),
  MIN("Order Region"),
  MIN("Order Country"),
  MIN("Market"),
  MIN(CAST("Order Profit Per Order" AS REAL))
FROM raw_import
WHERE "Order Id"              IS NOT NULL AND "Order Id"              <> ''
  AND "Order Customer Id"     IS NOT NULL AND "Order Customer Id"     <> ''
  AND "order date (DateOrders)" IS NOT NULL AND "order date (DateOrders)" <> ''
  AND "Order Status"          IS NOT NULL AND "Order Status"          <> ''
  -- Only require the customer to exist; profit is allowed to be NULL or negative
  AND CAST("Order Customer Id" AS INTEGER) IN (SELECT id FROM customers)
GROUP BY CAST("Order Id" AS INTEGER);

-- ─── 7. Order Items (item-level detail) ──────────────────────────────────────
-- One row per line item. Preserves full product, quantity, pricing, discount,
-- and per-item profit — INCLUDING negative item profits (losses).
-- "Benefit per order" in the raw data is the per-item profit contribution.
INSERT INTO order_items (id, order_id, product_id, quantity,
                         item_price, discount, discount_rate,
                         sales, item_profit, profit_ratio, order_item_total)
SELECT
  CAST("Order Item Id" AS INTEGER),
  CAST("Order Id" AS INTEGER),
  CAST("Order Item Cardprod Id" AS INTEGER),
  CAST("Order Item Quantity" AS INTEGER),
  CAST("Order Item Product Price" AS REAL),
  CAST("Order Item Discount" AS REAL),
  CAST("Order Item Discount Rate" AS REAL),
  CAST("Sales" AS REAL),
  CAST("Benefit per order" AS REAL),
  CAST("Order Item Profit Ratio" AS REAL),
  CAST("Order Item Total" AS REAL)
FROM raw_import
WHERE "Order Item Id"         IS NOT NULL AND "Order Item Id"         <> ''
  AND "Order Id"              IS NOT NULL AND "Order Id"              <> ''
  AND "Order Item Cardprod Id" IS NOT NULL AND "Order Item Cardprod Id" <> ''
  AND "Order Item Quantity"   IS NOT NULL AND "Order Item Quantity"   <> ''
  AND CAST("Order Item Quantity" AS INTEGER) > 0
  -- Link only to orders we successfully imported
  AND CAST("Order Id" AS INTEGER) IN (SELECT id FROM orders)
  -- Use INSERT OR IGNORE to skip any duplicate Order Item Ids gracefully
;

-- ─── 8. Shipping ─────────────────────────────────────────────────────────────
-- One shipping record per order. ship_date is now preserved so lead time
-- (order_date → ship_date) can be calculated in analysis.
-- Dates are stored as TEXT in the original format (M/D/YYYY H:MM);
-- parse them to a consistent format in Python/pandas with pd.to_datetime().
INSERT INTO shipping (order_id, shipping_mode, ship_date,
                      days_scheduled, days_actual,
                      delivery_status, late_delivery_risk)
SELECT
  CAST("Order Id" AS INTEGER),
  MIN("Shipping Mode"),
  MIN("shipping date (DateOrders)"),
  MIN(CAST("Days for shipment (scheduled)" AS REAL)),
  MIN(CAST("Days for shipping (real)" AS REAL)),
  MIN("Delivery Status"),
  MIN(CAST("Late_delivery_risk" AS INTEGER))
FROM raw_import
WHERE "Order Id"                      IS NOT NULL AND "Order Id"                      <> ''
  AND "Shipping Mode"                 IS NOT NULL AND "Shipping Mode"                 <> ''
  AND "Days for shipment (scheduled)" IS NOT NULL AND "Days for shipment (scheduled)" <> ''
  AND "Days for shipping (real)"      IS NOT NULL AND "Days for shipping (real)"      <> ''
  AND "Delivery Status"               IS NOT NULL AND "Delivery Status"               <> ''
  AND "Late_delivery_risk"            IS NOT NULL AND "Late_delivery_risk"            <> ''
  AND CAST("Order Id" AS INTEGER) IN (SELECT id FROM orders)
GROUP BY CAST("Order Id" AS INTEGER);

-- ─── 9. Remove incomplete trailing months ────────────────────────────────────
-- From Oct 2017 onward the source CSV recorded only 1 item per order instead
-- of the typical 3, causing a sudden artificial revenue drop.  Evidence:
--   • Order counts went UP  (~1 700 → ~2 100/month)  — not a real slowdown
--   • Items/order dropped to EXACTLY 1.0 overnight — a recording artifact
-- We detect affected orders by finding months where the average items-per-order
-- falls below 60 % of the dataset-wide median, then cascade-delete everything
-- linked to those orders so no other table is left with orphaned rows.

-- Step 1: identify the bad order IDs
CREATE TEMP TABLE bad_orders AS
WITH monthly_ratio AS (
    SELECT
        o.id AS order_id,
        substr(o.order_date,
            instr(o.order_date,'/')+
            instr(substr(o.order_date,instr(o.order_date,'/')+1),'/')+1, 4)
        || '-' ||
        printf('%02d',
            CAST(substr(o.order_date,1,instr(o.order_date,'/')-1) AS INTEGER))
            AS ym
    FROM orders o
),
month_stats AS (
    SELECT ym,
           COUNT(oi.id) * 1.0 / COUNT(DISTINCT o.id) AS items_per_order
    FROM orders o
    JOIN order_items oi ON o.id = oi.order_id
    JOIN monthly_ratio mr ON o.id = mr.order_id
    GROUP BY ym
),
median_val AS (
    SELECT AVG(items_per_order) AS med
    FROM (
        SELECT items_per_order
        FROM month_stats
        ORDER BY items_per_order
        LIMIT 2 OFFSET (SELECT COUNT(*)/2 - 1 FROM month_stats)
    )
),
bad_months AS (
    SELECT ym FROM month_stats, median_val
    WHERE items_per_order < med * 0.6
)
SELECT o.id AS order_id
FROM orders o
JOIN monthly_ratio mr ON o.id = mr.order_id
WHERE mr.ym IN (SELECT ym FROM bad_months);

-- Step 2: cascade delete from child tables first, then orders
DELETE FROM shipping    WHERE order_id IN (SELECT order_id FROM bad_orders);
DELETE FROM order_items WHERE order_id IN (SELECT order_id FROM bad_orders);
DELETE FROM orders      WHERE id        IN (SELECT order_id FROM bad_orders);

DROP TABLE bad_orders;
