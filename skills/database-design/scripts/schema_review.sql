-- PostgreSQL schema review: structural checks (runtime: query_diagnostics.sql).
-- psql -X -f schema_review.sql <conn>   Read-only; PostgreSQL 14+. Run it as a role that bypasses
-- RLS: pg_stats (9) hides tables whose policies apply to you. Rows are candidates, not verdicts.
-- 1-11: keys, indexes, types, RLS, tenancy. 12-14: what a reader with only the catalog can learn,
-- what each login role can do, vector columns.
-- The tenant column is assumed to be tenant_id; otherwise: psql -v tenant_column=workspace_id ...
\if :{?tenant_column}
\else
    \set tenant_column tenant_id
\endif

-- 1. FKs no index serves: a parent DELETE or key change scans the child. Served = a valid index led
--    by one of the FK's columns (after an optional leading tenant column), full or partial on
--    "<fk column> IS NOT NULL". A parent that is never deleted (parent_deletes = 0) may not need one.
SELECT c.conrelid::regclass AS child_table, c.conname,
       (SELECT string_agg(a.attname, ', ') FROM pg_attribute a
        WHERE a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)) AS fk_columns,
       c.confrelid::regclass AS parent_table,
       p.n_tup_del AS parent_deletes,
       pg_size_pretty(pg_relation_size(c.conrelid)) AS child_size
FROM pg_constraint c
LEFT JOIN pg_stat_all_tables p ON p.relid = c.confrelid
CROSS JOIN LATERAL (
    SELECT (SELECT a.attnum FROM pg_attribute a
            WHERE a.attrelid = c.conrelid AND a.attname = :'tenant_column' AND NOT a.attisdropped) AS tenant_att
) t
CROSS JOIN LATERAL (
    SELECT coalesce(nullif(array_remove(c.conkey, t.tenant_att), '{}'), c.conkey) AS lead_cols
) f
WHERE c.contype = 'f'
  AND NOT EXISTS (
      SELECT 1 FROM pg_index i
      CROSS JOIN LATERAL (SELECT string_to_array(i.indkey::text, ' ')::int2[] AS cols) k
      WHERE i.indrelid = c.conrelid AND i.indisvalid
        AND (i.indpred IS NULL
             OR pg_get_expr(i.indpred, i.indrelid) IN (
                    SELECT format('(%I IS NOT NULL)', a.attname) FROM pg_attribute a
                    WHERE a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)))
        AND (k.cols[1] = ANY (f.lead_cols)
             OR (k.cols[1] = t.tenant_att AND k.cols[2] = ANY (f.lead_cols))))
ORDER BY pg_relation_size(c.conrelid) DESC;

-- 2. Tables without a primary key.
SELECT c.oid::regclass AS table_name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND NOT c.relispartition
  AND n.nspname !~ '^(pg_|information_schema$)'
  AND NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conrelid = c.oid AND k.contype = 'p')
ORDER BY 1;

-- 3. Index candidates to drop: zero scans (constraint, replica-identity and FK-covering indexes
--    excluded), then redundant prefixes. Scan counts are per node and restart on reset, crash or
--    pg_upgrade; reconcile before and after any index change: references/indexing.md.
SELECT s.relid::regclass AS table_name, s.indexrelid::regclass AS index_name, s.idx_scan,
       (to_jsonb(s) ->> 'last_idx_scan')::timestamptz AS last_idx_scan,  -- PG16+
       coalesce((SELECT stats_reset::text FROM pg_stat_database WHERE datname = current_database()),
                'never reset') AS counting_since,
       pg_size_pretty(pg_relation_size(s.indexrelid)) AS size,
       pg_get_indexdef(s.indexrelid) AS restore_with
FROM pg_stat_user_indexes s
JOIN pg_index i ON i.indexrelid = s.indexrelid
WHERE s.idx_scan = 0
  AND i.indisvalid AND NOT i.indisunique AND NOT i.indisprimary AND NOT i.indisreplident
  AND NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = s.indexrelid)
  AND NOT EXISTS (                                   -- serves a foreign key (rule of section 1)
      SELECT 1 FROM pg_constraint f
      WHERE f.contype = 'f' AND f.conrelid = i.indrelid
        AND (string_to_array(i.indkey::text, ' ')::int2[])[1] = ANY (f.conkey))
ORDER BY pg_relation_size(s.indexrelid) DESC;

--    ...and redundant B-tree indexes: key columns that lead another valid index with the same
--    operator classes, collations, directions and predicate (a non-unique twin of a unique index
--    included). Drop unless the narrow one is hot and much smaller.
WITH pair AS (
    SELECT a.indrelid AS tbl, a.indexrelid AS idx, b.indexrelid AS cover
    FROM pg_index a
    JOIN pg_class ca ON ca.oid = a.indexrelid
    JOIN pg_index b ON b.indrelid = a.indrelid AND b.indexrelid <> a.indexrelid AND b.indisvalid
    JOIN pg_class cb ON cb.oid = b.indexrelid AND cb.relam = ca.relam
    WHERE ca.relam = (SELECT oid FROM pg_am WHERE amname = 'btree')
      AND a.indisvalid AND NOT a.indisunique AND NOT a.indisreplident
      AND a.indexprs IS NULL AND a.indnatts = a.indnkeyatts       -- no expressions, no INCLUDE
      AND NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = a.indexrelid)
      AND pg_get_expr(a.indpred, a.indrelid) IS NOT DISTINCT FROM pg_get_expr(b.indpred, b.indrelid)
      AND a.indnkeyatts <= b.indnkeyatts
      AND string_to_array(a.indkey::text, ' ')::int2[]
          = (string_to_array(b.indkey::text, ' ')::int2[])[1:a.indnkeyatts]
      AND string_to_array(a.indclass::text, ' ')::oid[]
          = (string_to_array(b.indclass::text, ' ')::oid[])[1:a.indnkeyatts]
      AND string_to_array(a.indcollation::text, ' ')::oid[]
          = (string_to_array(b.indcollation::text, ' ')::oid[])[1:a.indnkeyatts]
      AND string_to_array(a.indoption::text, ' ')::int2[]
          = (string_to_array(b.indoption::text, ' ')::int2[])[1:a.indnkeyatts]
      AND (a.indnkeyatts < b.indnkeyatts OR b.indisunique OR a.indexrelid > b.indexrelid))
SELECT p.tbl::regclass AS table_name, p.idx::regclass AS redundant_index,
       left(string_agg(p.cover::regclass::text, ', ' ORDER BY p.cover::regclass::text), 120)
           AS covered_by,
       s.idx_scan, pg_size_pretty(pg_relation_size(p.idx)) AS size,
       pg_get_indexdef(p.idx) AS restore_with
FROM pair p
LEFT JOIN pg_stat_all_indexes s ON s.indexrelid = p.idx
GROUP BY p.tbl, p.idx, s.idx_scan
ORDER BY pg_relation_size(p.idx) DESC;

-- 4. Sequence-fed smallint/integer keys by range used (references/migration-patterns.md, worked example).
SELECT c.oid::regclass AS table_name, a.attname AS column_name,
       format_type(a.atttypid, a.atttypmod) AS type, s.last_value,
       round(100.0 * s.last_value
             / CASE a.atttypid WHEN 'int2'::regtype THEN 32767 ELSE 2147483647 END, 1) AS pct_used
FROM pg_depend d
JOIN pg_class sc ON sc.oid = d.objid AND sc.relkind = 'S'
JOIN pg_namespace sn ON sn.oid = sc.relnamespace
JOIN pg_sequences s ON s.schemaname = sn.nspname AND s.sequencename = sc.relname
JOIN pg_class c ON c.oid = d.refobjid
JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
WHERE d.classid = 'pg_class'::regclass AND d.refclassid = 'pg_class'::regclass
  AND d.deptype IN ('a', 'i')
  AND a.atttypid IN ('int2'::regtype, 'int4'::regtype)
ORDER BY pct_used DESC NULLS LAST;

--    ...and foreign-key columns narrower than the key they reference.
SELECT c.conrelid::regclass AS child_table, c.conname,
       format_type(ca.atttypid, ca.atttypmod) AS child_type,
       format_type(pa.atttypid, pa.atttypmod) AS parent_type
FROM pg_constraint c
CROSS JOIN LATERAL unnest(c.conkey, c.confkey) AS k(child_att, parent_att)
JOIN pg_attribute ca ON ca.attrelid = c.conrelid AND ca.attnum = k.child_att
JOIN pg_attribute pa ON pa.attrelid = c.confrelid AND pa.attnum = k.parent_att
WHERE c.contype = 'f'
  AND ca.atttypid IN ('int2'::regtype, 'int4'::regtype) AND pa.atttypid = 'int8'::regtype;

-- 5. Float money (by name), the money type, timestamp without time zone (beside a zone column it
--    may be a future local time).
SELECT a.attrelid::regclass AS table_name, a.attname,
       format_type(a.atttypid, a.atttypmod) AS type,
       CASE WHEN a.atttypid = 'timestamp'::regtype
            THEN EXISTS (SELECT 1 FROM pg_attribute z
                         WHERE z.attrelid = a.attrelid AND z.attnum > 0 AND NOT z.attisdropped
                           AND z.attname ~* '(zone|tz)') END AS has_zone_column
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND a.attnum > 0 AND NOT a.attisdropped
  AND n.nspname !~ '^(pg_|information_schema$)'
  AND (a.atttypid IN ('timestamp'::regtype, 'money'::regtype)
       OR (a.atttypid IN ('real'::regtype, 'double precision'::regtype)
           AND a.attname ~* '(amount|price|cost|total|balance|fee|tax|salary|revenue|payment|charge|refund)'))
ORDER BY 1, 2;

-- 6. RLS enabled but not forced, or policies with RLS off; then login roles that bypass RLS.
--    Behind a generated API, also list each exposed schema's tables WHERE NOT relrowsecurity.
SELECT c.oid::regclass AS table_name, c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced,
       (SELECT count(*) FROM pg_policy p WHERE p.polrelid = c.oid) AS policies,
       pg_get_userbyid(c.relowner) AS owner
FROM pg_class c
WHERE c.relkind IN ('r', 'p')
  AND ((c.relrowsecurity AND NOT c.relforcerowsecurity)
       OR (NOT c.relrowsecurity AND EXISTS (SELECT 1 FROM pg_policy p WHERE p.polrelid = c.oid)));

SELECT rolname, rolsuper, rolbypassrls
FROM pg_roles
WHERE rolcanlogin AND (rolsuper OR rolbypassrls);

-- 7. Primary keys defaulting to random UUIDv4 (keys generated in the application do not show).
SELECT c.conrelid::regclass AS table_name, a.attname,
       pg_get_expr(d.adbin, d.adrelid) AS default_expr
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
WHERE c.contype = 'p'
  AND pg_get_expr(d.adbin, d.adrelid) ~ '(gen_random_uuid|uuid_generate_v4|uuidv4)\(';

-- 8. Constraints added NOT VALID and never validated.
SELECT conrelid::regclass AS table_name, conname, contype
FROM pg_constraint
WHERE NOT convalidated
ORDER BY 1, 2;

-- 9. Mostly-NULL columns (ANALYZE first).
SELECT schemaname, tablename, attname, null_frac
FROM pg_stats
WHERE schemaname !~ '^(pg_|information_schema$)' AND null_frac > 0.5
ORDER BY null_frac DESC
LIMIT 20;

-- 10. Largest relations, with bytes per row for sizing (NULL until ANALYZE).
SELECT c.oid::regclass AS relation, c.reltuples::bigint AS est_rows,
       pg_size_pretty(pg_table_size(c.oid)) AS table_and_toast,
       pg_size_pretty(pg_indexes_size(c.oid)) AS indexes,
       pg_size_pretty(pg_total_relation_size(c.oid)) AS total,
       CASE WHEN c.reltuples >= 10000 THEN round(pg_table_size(c.oid) / c.reltuples) END AS bytes_per_row
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'm')
  AND n.nspname !~ '^(pg_|information_schema$)'
ORDER BY pg_total_relation_size(c.oid) DESC
LIMIT 20;

-- 11. Pooled tenancy (tables with the tenant column): unique indexes other than the PK
--     and FKs to tenant-owned parents that omit it, and tables without RLS.
WITH t AS (
    SELECT c.oid AS relid, a.attnum, c.relrowsecurity
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_attribute a ON a.attrelid = c.oid AND a.attname = :'tenant_column' AND NOT a.attisdropped
    WHERE c.relkind IN ('r', 'p') AND NOT c.relispartition
      AND n.nspname !~ '^(pg_|information_schema$)'
)
SELECT t.relid::regclass AS table_name, 'unique without the tenant column' AS finding,
       pg_get_indexdef(i.indexrelid) AS detail
FROM t JOIN pg_index i ON i.indrelid = t.relid
WHERE i.indisunique AND NOT i.indisprimary AND NOT (t.attnum = ANY (i.indkey))
UNION ALL
SELECT t.relid::regclass, 'FK without the tenant column', pg_get_constraintdef(f.oid)
FROM t
JOIN pg_constraint f ON f.conrelid = t.relid AND f.contype = 'f'
JOIN t p ON p.relid = f.confrelid
WHERE NOT (t.attnum = ANY (f.conkey))
UNION ALL
SELECT t.relid::regclass, 'RLS not enabled', NULL
FROM t
WHERE NOT t.relrowsecurity
ORDER BY 1, 2;

-- 12. Undeclared references: *_id columns that no foreign key covers (the tenant column excluded).
--     A reader with only the catalog cannot find the join, and nothing stops an orphan.
SELECT c.oid::regclass AS table_name, a.attname AS column_name,
       format_type(a.atttypid, a.atttypmod) AS type
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND NOT c.relispartition AND a.attnum > 0 AND NOT a.attisdropped
  AND n.nspname !~ '^(pg_|information_schema$)'
  AND a.attname ~ '_id$' AND a.attname <> :'tenant_column'
  AND NOT EXISTS (SELECT 1 FROM pg_constraint k
                  WHERE k.conrelid = c.oid AND k.contype = 'f' AND a.attnum = ANY (k.conkey))
ORDER BY 1, 2;

--     ...and closed sets left open: status-like text columns with neither a CHECK nor a foreign key,
--     so the catalog cannot say which values are legal.
SELECT c.oid::regclass AS table_name, a.attname AS column_name
FROM pg_attribute a
JOIN pg_class c ON c.oid = a.attrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p') AND NOT c.relispartition AND a.attnum > 0 AND NOT a.attisdropped
  AND n.nspname !~ '^(pg_|information_schema$)'
  AND a.atttypid IN ('text'::regtype, 'varchar'::regtype)
  AND a.attname ~ '(^|_)(status|state|type|kind|role|category|level|mode|tier|stage)$'
  AND NOT EXISTS (SELECT 1 FROM pg_constraint k
                  WHERE k.conrelid = c.oid AND k.contype IN ('c', 'f') AND a.attnum = ANY (k.conkey))
ORDER BY 1, 2;

-- 13. Principals: what each login role can do in this database. A reader or an agent should show
--     owns_tables = f, writable_tables = 0, create_in_schemas = 0, bypasses_rls = f. Role settings
--     (timeouts, read-only) are defaults the session can change: references/access.md.
SELECT r.rolname, r.rolsuper AS superuser, r.rolbypassrls AS bypasses_rls, r.rolconnlimit AS conn_limit,
       EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
               WHERE c.relowner = r.oid AND c.relkind IN ('r', 'p')
                 AND n.nspname !~ '^(pg_|information_schema$)') AS owns_tables,
       (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind IN ('r', 'p') AND n.nspname !~ '^(pg_|information_schema$)'
          AND has_table_privilege(r.oid, c.oid, 'INSERT, UPDATE, DELETE, TRUNCATE')) AS writable_tables,
       (SELECT count(*) FROM pg_namespace n
        WHERE n.nspname !~ '^(pg_|information_schema$)'
          AND has_schema_privilege(r.oid, n.oid, 'CREATE')) AS create_in_schemas,
       has_database_privilege(r.oid, current_database(), 'TEMP') AS temp_tables,
       (SELECT string_agg(s, ', ') FROM pg_db_role_setting d, unnest(d.setconfig) s
        WHERE d.setrole = r.oid
          AND d.setdatabase IN (0, (SELECT oid FROM pg_database WHERE datname = current_database())))
           AS role_settings
FROM pg_roles r
WHERE r.rolcanlogin AND r.rolname !~ '^pg_'
ORDER BY r.rolsuper DESC, writable_tables DESC, r.rolname;

--     ...policies that apply to every role (permissive policies are OR-ed, so a reader inherits the
--     application's), and SECURITY DEFINER functions with a caller-controlled search_path or
--     executable by everyone.
SELECT p.polrelid::regclass::text AS object, p.polname AS name, 'policy without TO: applies to every role' AS finding
FROM pg_policy p
WHERE p.polroles = '{0}'
UNION ALL
SELECT f.oid::regprocedure::text, NULL, 'SECURITY DEFINER without a fixed search_path'
FROM pg_proc f JOIN pg_namespace n ON n.oid = f.pronamespace
WHERE f.prosecdef AND n.nspname !~ '^(pg_|information_schema$)'
  AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(f.proconfig, '{}')) cfg WHERE cfg LIKE 'search_path=%')
UNION ALL
SELECT f.oid::regprocedure::text, NULL, 'SECURITY DEFINER executable by PUBLIC'
FROM pg_proc f JOIN pg_namespace n ON n.oid = f.pronamespace
WHERE f.prosecdef AND n.nspname !~ '^(pg_|information_schema$)'
  AND has_function_privilege('public', f.oid, 'EXECUTE')
ORDER BY 3, 1;

-- 14. Vector columns (pgvector), with their approximate indexes and operator classes. The query's
--     operator must match the class (<=> cosine, <-> L2, <#> inner product); an untyped column or
--     one without an index is searched exactly: references/ai-data.md.
SELECT a.attrelid::regclass AS table_name, a.attname AS column_name,
       format_type(a.atttypid, a.atttypmod) AS type,
       (SELECT string_agg(i.indexrelid::regclass::text || ' (' || am.amname || ', ' || oc.opcname || ')', '; ')
        FROM pg_index i
        JOIN pg_class ic ON ic.oid = i.indexrelid
        JOIN pg_am am ON am.oid = ic.relam
        JOIN pg_opclass oc ON oc.oid = i.indclass[0]
        WHERE i.indrelid = a.attrelid AND i.indisvalid AND a.attnum = ANY (i.indkey)
          AND am.amname NOT IN ('btree', 'hash', 'gin', 'gist', 'spgist', 'brin')) AS ann_indexes,
       s.n_tup_upd AS row_updates, s.n_tup_del AS row_deletes
FROM pg_attribute a
JOIN pg_type t ON t.oid = a.atttypid
JOIN pg_class c ON c.oid = a.attrelid
LEFT JOIN pg_stat_all_tables s ON s.relid = c.oid
WHERE t.typname IN ('vector', 'halfvec', 'sparsevec')
  AND c.relkind IN ('r', 'p') AND a.attnum > 0 AND NOT a.attisdropped
ORDER BY 1, 2;
