SELECT
    asset_id,
    asset_name,
    ticker_symbol,
    asset_category,
    unit_measure,
    source_authority
FROM {{ ref('mapping_asset') }}