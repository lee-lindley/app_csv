whenever sqlerror continue
prompt ok for drop to fail if type does not exist
drop type app_csv_udt;
prompt ok if drop failed for type does not exist
whenever sqlerror exit failure
set define on
--
-- name these any way you like. If you already have types that match these, give those names
-- and comment out the compiles for them.
--
define d_arr_integer_udt="arr_integer_udt"
define d_arr_varchar2_udt="arr_varchar2_udt"
define d_arr_clob_udt="arr_clob_udt"
define d_arr_arr_clob_udt="arr_arr_clob_udt"
--
define subdir=plsql_utilities/app_types
prompt &&subdir/arr_varchar2_udt.tps
@@&&subdir/arr_varchar2_udt.tps
prompt &&subdir/arr_integer_udt.tps
@@&&subdir/arr_integer_udt.tps
prompt &&subdir/arr_clob_udt.tps
@@&&subdir/arr_clob_udt.tps
prompt &&subdir/arr_arr_clob_udt.tps
@@&&subdir/arr_arr_clob_udt.tps
-- these settings are a personal preference. 
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
define subdir=plsql_utilities/app_dbms_sql
prompt &&subdir/install_app_dbms_sql.sql
@@&&subdir/install_app_dbms_sql.sql
--
prompt app_csv_udt.tps
@@app_csv_udt.tps
prompt app_csv_udt.tpb
@@app_csv_udt.tpb
ALTER SESSION SET plsql_optimize_level=2;
ALTER SESSION SET plsql_code_type = INTERPRETED;
--
prompt running compile_schema for invalid objects
BEGIN
    DBMS_UTILITY.compile_schema( schema => SYS_CONTEXT('userenv','current_schema')
                                ,compile_all => FALSE
                                ,reuse_settings => TRUE
                            );
END;
/

