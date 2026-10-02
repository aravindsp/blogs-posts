with source as (

    select * from {{ source('tpch', 'orders') }}

),

renamed as (

    select
        o_orderkey      as order_key,
        o_custkey       as customer_key,
        o_orderstatus   as order_status_code,
        case o_orderstatus
            when 'F' then 'fulfilled'
            when 'O' then 'open'
            when 'P' then 'partially_fulfilled'
        end             as order_status,
        o_totalprice    as total_price,
        o_orderdate     as order_date,
        o_orderpriority as order_priority,
        o_clerk         as clerk_name,
        o_shippriority  as ship_priority,
        _loaded_at
    from source

)

select * from renamed
