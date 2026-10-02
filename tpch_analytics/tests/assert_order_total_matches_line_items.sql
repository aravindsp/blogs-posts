-- The order header total should equal the sum of its line items.
-- Source systems round each line, so allow up to $1 of rounding difference.
select
    order_key,
    total_price,
    total_amount,
    total_price - total_amount as difference
from {{ ref('fct_orders') }}
where abs(total_price - total_amount) > 1.00
