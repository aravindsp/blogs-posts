with line_items as (

    select * from {{ ref('stg_tpch__line_items') }}

),

orders as (

    select * from {{ ref('stg_tpch__orders') }}

)

select
    line_items.order_item_key,
    line_items.order_key,
    line_items.line_number,
    orders.customer_key,
    line_items.part_key,
    line_items.supplier_key,
    orders.order_date,
    orders.order_status,
    line_items.ship_date,
    line_items.commit_date,
    line_items.receipt_date,
    line_items.ship_mode,
    line_items.return_flag,
    line_items.quantity,
    line_items.extended_price                                   as gross_amount,
    line_items.extended_price * line_items.discount_rate        as discount_amount,
    line_items.extended_price * (1 - line_items.discount_rate)  as net_amount,
    line_items.extended_price * (1 - line_items.discount_rate)
        * line_items.tax_rate                                   as tax_amount,
    line_items.extended_price * (1 - line_items.discount_rate)
        * (1 + line_items.tax_rate)                             as total_amount,
    line_items.receipt_date > line_items.commit_date            as is_late_delivery,
    line_items._loaded_at
from line_items
inner join orders
    on line_items.order_key = orders.order_key
