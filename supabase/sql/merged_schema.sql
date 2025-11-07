Explanation: merged_schema.sql was truncated and caused an unterminated dollar-quoted string error when executed; replace it with the full canonical master script (same content as fix_schema.sql) so it is syntactically complete and safe to run in Supabase.
-- ====================================================================

