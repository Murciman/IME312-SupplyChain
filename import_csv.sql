
DROP TABLE IF EXISTS raw_import;
CREATE TABLE raw_import(
  "Type" TEXT,
  "Days for shipping (real)" TEXT,
  "Days for shipment (scheduled)" TEXT,
  "Benefit per order" TEXT,
  "Sales per customer" TEXT,
  "Delivery Status" TEXT,
  "Late_delivery_risk" TEXT,
  "Category Id" TEXT,
  "Category Name" TEXT,
  "Customer City" TEXT,
  "Customer Country" TEXT,
  "Customer Email" TEXT,
  "Customer Fname" TEXT,
  "Customer Id" TEXT,
  "Customer Lname" TEXT,
  "Customer Password" TEXT,
  "Customer Segment" TEXT,
  "Customer State" TEXT,
  "Customer Street" TEXT,
  "Customer Zipcode" TEXT,
  "Department Id" TEXT,
  "Department Name" TEXT,
  "Latitude" TEXT,
  "Longitude" TEXT,
  "Market" TEXT,
  "Order City" TEXT,
  "Order Country" TEXT,
  "Order Customer Id" TEXT,
  "order date (DateOrders)" TEXT,
  "Order Id" TEXT,
  "Order Item Cardprod Id" TEXT,
  "Order Item Discount" TEXT,
  "Order Item Discount Rate" TEXT,
  "Order Item Id" TEXT,
  "Order Item Product Price" TEXT,
  "Order Item Profit Ratio" TEXT,
  "Order Item Quantity" TEXT,
  "Sales" TEXT,
  "Order Item Total" TEXT,
  "Order Profit Per Order" TEXT,
  "Order Region" TEXT,
  "Order State" TEXT,
  "Order Status" TEXT,
  "Order Zipcode" TEXT,
  "Product Card Id" TEXT,
  "Product Category Id" TEXT,
  "Product Description" TEXT,
  "Product Image" TEXT,
  "Product Name" TEXT,
  "Product Price" TEXT,
  "Product Status" TEXT,
  "shipping date (DateOrders)" TEXT,
  "Shipping Mode" TEXT
);

.mode csv
.import DataCoSupplyChainDataset.csv raw_import

DELETE FROM raw_import
WHERE "Type" = 'Type' AND "Order Id" = 'Order Id';

INSERT INTO categories (id, category_name)
SELECT DISTINCT
  CAST("Category Id" AS INTEGER),
  "Category Name"
FROM raw_import
WHERE "Category Id" IS NOT NULL AND "Category Name" IS NOT NULL;

INSERT INTO departments (id, department_name, market)
SELECT
  CAST("Department Id" AS INTEGER),
  MIN("Department Name"),
  MIN("Market")
FROM raw_import
WHERE "Department Id" IS NOT NULL AND "Department Name" IS NOT NULL AND "Market" IS NOT NULL
GROUP BY "Department Id";

INSERT INTO customers (id, segment, city, state, country, market)
SELECT
  CAST("Customer Id" AS INTEGER),
  MIN("Customer Segment"),
  MIN("Customer City"),
  MIN("Customer State"),
  MIN("Customer Country"),
  MIN("Market")
FROM raw_import
WHERE "Customer Id" IS NOT NULL
  AND "Customer Segment" IS NOT NULL
  AND "Customer City" IS NOT NULL
  AND "Customer State" IS NOT NULL
  AND "Customer Country" IS NOT NULL
  AND "Market" IS NOT NULL
GROUP BY "Customer Id";

INSERT INTO products (id, category_id, department_id, product_name, product_price)
SELECT
  CAST("Product Card Id" AS INTEGER),
  MIN(CAST("Product Category Id" AS INTEGER)),
  MIN(CAST("Department Id" AS INTEGER)),
  MIN("Product Name"),
  MIN(CAST("Product Price" AS REAL))
FROM raw_import
WHERE "Product Card Id" IS NOT NULL
  AND "Product Card Id" <> ''
  AND CAST("Product Card Id" AS INTEGER) > 0
  AND "Product Category Id" IS NOT NULL
  AND "Product Category Id" <> ''
  AND CAST("Product Category Id" AS INTEGER) > 0
  AND "Department Id" IS NOT NULL
  AND "Department Id" <> ''
  AND CAST("Department Id" AS INTEGER) > 0
  AND "Product Name" IS NOT NULL
  AND "Product Price" IS NOT NULL
  AND "Product Price" <> ''
  AND CAST("Product Price" AS REAL) >= 0
GROUP BY CAST("Product Card Id" AS INTEGER);

INSERT INTO orders (id, customer_id, product_id, order_date, quantity, profit_per_order, order_status)
SELECT
  CAST("Order Id" AS INTEGER),
  MIN(CAST("Order Customer Id" AS INTEGER)),
  MIN(CAST("Product Card Id" AS INTEGER)),
  MIN("order date (DateOrders)"),
  SUM(CAST("Order Item Quantity" AS INTEGER)),
  SUM(CAST("Order Profit Per Order" AS REAL)),
  MIN("Order Status")
FROM raw_import
WHERE "Order Id" IS NOT NULL
  AND "Order Customer Id" IS NOT NULL
  AND "Product Card Id" IS NOT NULL
  AND "order date (DateOrders)" IS NOT NULL
  AND "Order Item Quantity" IS NOT NULL
  AND CAST("Order Item Quantity" AS INTEGER) > 0
  AND "Order Profit Per Order" IS NOT NULL
  AND CAST("Order Profit Per Order" AS REAL) >= 0
  AND "Order Status" IS NOT NULL
GROUP BY "Order Id";

INSERT INTO shipping (order_id, shipping_mode, days_scheduled, days_actual, delivery_status, late_delivery_risk)
SELECT
  CAST("Order Id" AS INTEGER),
  MIN("Shipping Mode"),
  MIN(CAST("Days for shipment (scheduled)" AS INTEGER)),
  MIN(CAST("Days for shipping (real)" AS INTEGER)),
  MIN("Delivery Status"),
  MIN(CAST("Late_delivery_risk" AS INTEGER))
FROM raw_import
WHERE "Order Id" IS NOT NULL
  AND "Order Id" <> ''
  AND CAST("Order Id" AS INTEGER) > 0
  AND CAST("Order Id" AS INTEGER) IN (SELECT id FROM orders)
  AND "Shipping Mode" IS NOT NULL
  AND "Days for shipment (scheduled)" IS NOT NULL
  AND "Days for shipping (real)" IS NOT NULL
  AND "Delivery Status" IS NOT NULL
  AND "Late_delivery_risk" IS NOT NULL
GROUP BY CAST("Order Id" AS INTEGER);

