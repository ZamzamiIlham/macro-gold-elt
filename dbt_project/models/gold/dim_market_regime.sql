SELECT 
    regime_id,
    regime_label,
    risk_level,
    action_recommendation
FROM {{ ref('mapping_regime') }}