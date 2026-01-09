-- =============================================================================
-- Stripe Connector - ERD Registration
-- =============================================================================

-- 1. Insert connector
INSERT INTO connectors (id, name, description) VALUES 
('stripe', 'Stripe', 'Stripe payments platform connector for customers, charges, subscriptions, invoices, and more.');

-- 2. Insert tables
INSERT INTO connector_tables (connector_id, name, ingestion_mode, cursor_column, docs_url, position_x, position_y) VALUES
('stripe', 'customers', 'incremental', 'created', 'https://docs.stripe.com/api/customers', 500, 50),
('stripe', 'charges', 'incremental', 'created', 'https://docs.stripe.com/api/charges', 200, 200),
('stripe', 'payment_intents', 'incremental', 'created', 'https://docs.stripe.com/api/payment_intents', 350, 200),
('stripe', 'payment_methods', 'incremental', 'created', 'https://docs.stripe.com/api/payment_methods', 650, 200),
('stripe', 'refunds', 'incremental', 'created', 'https://docs.stripe.com/api/refunds', 50, 350),
('stripe', 'disputes', 'incremental', 'created', 'https://docs.stripe.com/api/disputes', 200, 350),
('stripe', 'subscriptions', 'incremental', 'created', 'https://docs.stripe.com/api/subscriptions', 800, 50),
('stripe', 'invoices', 'incremental', 'created', 'https://docs.stripe.com/api/invoices', 950, 200),
('stripe', 'invoice_items', 'incremental', 'created', 'https://docs.stripe.com/api/invoiceitems', 1100, 200),
('stripe', 'products', 'incremental', 'created', 'https://docs.stripe.com/api/products', 500, 350),
('stripe', 'prices', 'incremental', 'created', 'https://docs.stripe.com/api/prices', 650, 350),
('stripe', 'plans', 'incremental', 'created', 'https://docs.stripe.com/api/plans', 800, 350),
('stripe', 'coupons', 'incremental', 'created', 'https://docs.stripe.com/api/coupons', 950, 350),
('stripe', 'balance_transactions', 'incremental', 'created', 'https://docs.stripe.com/api/balance_transactions', 350, 500),
('stripe', 'payouts', 'incremental', 'created', 'https://docs.stripe.com/api/payouts', 500, 500),
('stripe', 'events', 'incremental', 'created', 'https://docs.stripe.com/api/events', 650, 500);

-- 3. Customers columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('email', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('name', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('phone', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('balance', 'BIGINT', 8, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('delinquent', 'BOOLEAN', 10, FALSE, FALSE, NULL, NULL),
    ('address_line1', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('address_line2', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('address_city', 'STRING', 13, FALSE, FALSE, NULL, NULL),
    ('address_state', 'STRING', 14, FALSE, FALSE, NULL, NULL),
    ('address_postal_code', 'STRING', 15, FALSE, FALSE, NULL, NULL),
    ('address_country', 'STRING', 16, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 17, FALSE, FALSE, NULL, NULL),
    ('deleted', 'BOOLEAN', 18, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'customers';

-- 4. Charges columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('customer', 'STRING', 4, FALSE, TRUE, 'customers', 'id'),
    ('amount', 'BIGINT', 5, FALSE, FALSE, NULL, NULL),
    ('amount_captured', 'BIGINT', 6, FALSE, FALSE, NULL, NULL),
    ('amount_refunded', 'BIGINT', 7, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('paid', 'BOOLEAN', 10, FALSE, FALSE, NULL, NULL),
    ('refunded', 'BOOLEAN', 11, FALSE, FALSE, NULL, NULL),
    ('captured', 'BOOLEAN', 12, FALSE, FALSE, NULL, NULL),
    ('payment_intent', 'STRING', 13, FALSE, TRUE, 'payment_intents', 'id'),
    ('payment_method', 'STRING', 14, FALSE, TRUE, 'payment_methods', 'id'),
    ('billing_details', 'STRING', 15, FALSE, FALSE, NULL, NULL),
    ('outcome', 'STRING', 16, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 17, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'charges';

-- 5. Payment Intents columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('customer', 'STRING', 4, FALSE, TRUE, 'customers', 'id'),
    ('amount', 'BIGINT', 5, FALSE, FALSE, NULL, NULL),
    ('amount_received', 'BIGINT', 6, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('payment_method', 'STRING', 9, FALSE, TRUE, 'payment_methods', 'id'),
    ('charges', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('cancellation_reason', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 12, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'payment_intents';

-- 6. Payment Methods columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('customer', 'STRING', 4, FALSE, TRUE, 'customers', 'id'),
    ('type', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('billing_details', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('card', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 8, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'payment_methods';

-- 7. Refunds columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('charge', 'STRING', 3, FALSE, TRUE, 'charges', 'id'),
    ('amount', 'BIGINT', 4, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('reason', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('receipt_number', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('failure_reason', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 10, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'refunds';

-- 8. Disputes columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('charge', 'STRING', 3, FALSE, TRUE, 'charges', 'id'),
    ('amount', 'BIGINT', 4, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('reason', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('evidence', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('is_charge_refundable', 'BOOLEAN', 9, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 10, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'disputes';

-- 9. Subscriptions columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('customer', 'STRING', 4, FALSE, TRUE, 'customers', 'id'),
    ('status', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('current_period_start', 'BIGINT', 6, FALSE, FALSE, NULL, NULL),
    ('current_period_end', 'BIGINT', 7, FALSE, FALSE, NULL, NULL),
    ('cancel_at_period_end', 'BOOLEAN', 8, FALSE, FALSE, NULL, NULL),
    ('canceled_at', 'BIGINT', 9, FALSE, FALSE, NULL, NULL),
    ('trial_start', 'BIGINT', 10, FALSE, FALSE, NULL, NULL),
    ('trial_end', 'BIGINT', 11, FALSE, FALSE, NULL, NULL),
    ('items', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('default_payment_method', 'STRING', 13, FALSE, TRUE, 'payment_methods', 'id'),
    ('metadata', 'STRING', 14, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'subscriptions';

-- 10. Invoices columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('customer', 'STRING', 4, FALSE, TRUE, 'customers', 'id'),
    ('subscription', 'STRING', 5, FALSE, TRUE, 'subscriptions', 'id'),
    ('status', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('amount_due', 'BIGINT', 7, FALSE, FALSE, NULL, NULL),
    ('amount_paid', 'BIGINT', 8, FALSE, FALSE, NULL, NULL),
    ('amount_remaining', 'BIGINT', 9, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('invoice_pdf', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('hosted_invoice_url', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('lines', 'STRING', 13, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 14, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'invoices';

-- 11. Invoice Items columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('customer', 'STRING', 3, FALSE, TRUE, 'customers', 'id'),
    ('invoice', 'STRING', 4, FALSE, TRUE, 'invoices', 'id'),
    ('amount', 'BIGINT', 5, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('quantity', 'BIGINT', 8, FALSE, FALSE, NULL, NULL),
    ('unit_amount', 'BIGINT', 9, FALSE, FALSE, NULL, NULL),
    ('period_start', 'BIGINT', 10, FALSE, FALSE, NULL, NULL),
    ('period_end', 'BIGINT', 11, FALSE, FALSE, NULL, NULL),
    ('discounts', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 13, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'invoice_items';

-- 12. Products columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('name', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('active', 'BOOLEAN', 6, FALSE, FALSE, NULL, NULL),
    ('type', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('images', 'ARRAY<STRING>', 8, FALSE, FALSE, NULL, NULL),
    ('tax_code', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('shippable', 'BOOLEAN', 10, FALSE, FALSE, NULL, NULL),
    ('deleted', 'BOOLEAN', 11, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 12, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'products';

-- 13. Prices columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('product', 'STRING', 4, FALSE, TRUE, 'products', 'id'),
    ('active', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('unit_amount', 'BIGINT', 7, FALSE, FALSE, NULL, NULL),
    ('billing_scheme', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('type', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('recurring', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('tiers', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 12, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'prices';

-- 14. Plans columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('product', 'STRING', 4, FALSE, TRUE, 'products', 'id'),
    ('active', 'BOOLEAN', 5, FALSE, FALSE, NULL, NULL),
    ('amount', 'BIGINT', 6, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('interval', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('interval_count', 'BIGINT', 9, FALSE, FALSE, NULL, NULL),
    ('usage_type', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('trial_period_days', 'BIGINT', 11, FALSE, FALSE, NULL, NULL),
    ('tiers', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('deleted', 'BOOLEAN', 13, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 14, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'plans';

-- 15. Coupons columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('name', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('amount_off', 'BIGINT', 5, FALSE, FALSE, NULL, NULL),
    ('percent_off', 'DOUBLE', 6, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('duration', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('duration_in_months', 'BIGINT', 9, FALSE, FALSE, NULL, NULL),
    ('max_redemptions', 'BIGINT', 10, FALSE, FALSE, NULL, NULL),
    ('times_redeemed', 'BIGINT', 11, FALSE, FALSE, NULL, NULL),
    ('valid', 'BOOLEAN', 12, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 13, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'coupons';

-- 16. Balance Transactions columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('amount', 'BIGINT', 3, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('net', 'BIGINT', 5, FALSE, FALSE, NULL, NULL),
    ('fee', 'BIGINT', 6, FALSE, FALSE, NULL, NULL),
    ('type', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('source', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('available_on', 'BIGINT', 10, FALSE, FALSE, NULL, NULL),
    ('description', 'STRING', 11, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'balance_transactions';

-- 17. Payouts columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('amount', 'BIGINT', 4, FALSE, FALSE, NULL, NULL),
    ('currency', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('arrival_date', 'BIGINT', 6, FALSE, FALSE, NULL, NULL),
    ('status', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('type', 'STRING', 8, FALSE, FALSE, NULL, NULL),
    ('method', 'STRING', 9, FALSE, FALSE, NULL, NULL),
    ('destination', 'STRING', 10, FALSE, FALSE, NULL, NULL),
    ('failure_code', 'STRING', 11, FALSE, FALSE, NULL, NULL),
    ('failure_message', 'STRING', 12, FALSE, FALSE, NULL, NULL),
    ('metadata', 'STRING', 13, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'payouts';

-- 18. Events columns
INSERT INTO table_columns (table_id, name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
SELECT t.id, col.name, col.data_type, col.ordinal_position, col.is_primary_key, col.is_foreign_key, col.references_table, col.references_column
FROM connector_tables t
CROSS JOIN (VALUES
    ('id', 'STRING', 0, TRUE, FALSE, NULL, NULL),
    ('object', 'STRING', 1, FALSE, FALSE, NULL, NULL),
    ('created', 'BIGINT', 2, FALSE, FALSE, NULL, NULL),
    ('livemode', 'BOOLEAN', 3, FALSE, FALSE, NULL, NULL),
    ('type', 'STRING', 4, FALSE, FALSE, NULL, NULL),
    ('data', 'STRING', 5, FALSE, FALSE, NULL, NULL),
    ('api_version', 'STRING', 6, FALSE, FALSE, NULL, NULL),
    ('request', 'STRING', 7, FALSE, FALSE, NULL, NULL),
    ('pending_webhooks', 'BIGINT', 8, FALSE, FALSE, NULL, NULL)
) AS col(name, data_type, ordinal_position, is_primary_key, is_foreign_key, references_table, references_column)
WHERE t.connector_id = 'stripe' AND t.name = 'events';

