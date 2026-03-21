-- Exclude archived groups from get_overall_balances results.
DROP FUNCTION IF EXISTS get_overall_balances(UUID);

CREATE OR REPLACE FUNCTION get_overall_balances(p_user_id UUID)
RETURNS TABLE (
  group_id     UUID,
  group_name   TEXT,
  currency     TEXT,
  net_balance  NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  WITH paid AS (
    SELECT
      e.group_id AS gid,
      COALESCE(SUM(
        e.amount * CASE
          WHEN e.currency = g.currency THEN 1
          ELSE COALESCE(
            (SELECT rate FROM group_exchange_rates ger
             WHERE ger.group_id = e.group_id AND ger.currency = e.currency),
            1
          )
        END
      ), 0) AS total
    FROM expenses e
    JOIN groups g ON g.id = e.group_id
    WHERE e.paid_by = p_user_id
    GROUP BY e.group_id
  ),
  owed AS (
    SELECT
      e.group_id AS gid,
      COALESCE(SUM(
        es.amount * CASE
          WHEN e.currency = g.currency THEN 1
          ELSE COALESCE(
            (SELECT rate FROM group_exchange_rates ger
             WHERE ger.group_id = e.group_id AND ger.currency = e.currency),
            1
          )
        END
      ), 0) AS total
    FROM expense_splits es
    JOIN expenses e ON e.id = es.expense_id
    JOIN groups g ON g.id = e.group_id
    WHERE es.user_id = p_user_id
    GROUP BY e.group_id
  ),
  settled_out AS (
    SELECT s.group_id AS gid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.from_user = p_user_id
    GROUP BY s.group_id
  ),
  settled_in AS (
    SELECT s.group_id AS gid, COALESCE(SUM(s.amount), 0) AS total
    FROM settlements s
    WHERE s.to_user = p_user_id
    GROUP BY s.group_id
  )
  SELECT
    g.id,
    g.name,
    g.currency,
    COALESCE(pd.total, 0) - COALESCE(ow.total, 0)
      + COALESCE(so.total, 0) - COALESCE(si.total, 0) AS net_balance
  FROM group_members gm
  JOIN groups g ON g.id = gm.group_id
  LEFT JOIN paid pd ON pd.gid = g.id
  LEFT JOIN owed ow ON ow.gid = g.id
  LEFT JOIN settled_out so ON so.gid = g.id
  LEFT JOIN settled_in si ON si.gid = g.id
  WHERE gm.user_id = p_user_id
    AND g.status != 'archived';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;
