with order_items as (

    select * from {{ ref('fct_order_items') }}

),

orders as (

    select * from {{ ref('stg_tpch__orders') }}

),

order_totals as (

    select
        order_key,
        count(*)                 as item_count,
        sum(quantity)            as total_quantity,
        sum(gross_amount)        as gross_amount,
        sum(discount_amount)     as discount_amount,
        sum(net_amount)          as net_amount,
        sum(tax_amount)          as tax_amount,
        sum(total_amount)        as total_amount,
        sum(case when is_late_delivery then 1 else 0 end) as late_item_count
    from order_items
    group by order_key

)

select
    orders.order_key,
    orders.customer_key,
    orders.order_date,
    orders.order_status,
    orders.order_priority,
    orders.total_price,
    order_totals.item_count,
    order_totals.total_quantity,
    order_totals.gross_amount,
    order_totals.discount_amount,
    order_totals.net_amount,
    order_totals.tax_amount,
    order_totals.total_amount,
    order_totals.late_item_count
from orders
inner join order_totals
    on orders.order_key = order_totals.order_key
