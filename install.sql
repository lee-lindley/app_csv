whenever sqlerror continue
prompt ok for drop to fail if type does not exist
drop type app_csv_udt;
prompt ok if drop failed for type does not exist
whenever sqlerror exit failure
set define on
define subdir=plsql_utilities/app_types
prompt &&subdir/arr_varchar2_udt.tps
@&&subdir/arr_varchar2_udt.tps
prompt &&subdir/arr_clob_udt.tps
@&&subdir/arr_clob_udt.tps
prompt &&subdir/arr_arr_clob_udt.tps
@&&subdir/arr_arr_clob_udt.tps
-- these settings are a personal preference. 
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
define subdir=plsql_utilities/app_dbms_sql
prompt &&subdir/install_app_dbms_sql.sql
@&&subdir/install_app_dbms_sql.sql
--
prompt app_csv_udt.tps
@app_csv_udt.tps
prompt app_csv_udt.tpb
@app_csv_udt.tpb
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

