whenever sqlerror exit failure
set define on
-- if you already have a suitable type TABLE OF VARCHAR2(4000) then you can
-- do a global substitution in app_csv_udt.tbps and app_csv_udt.tbp, 
-- then comment out this call for arr_varchar2_udt.
define subdir=plsql_utilities
prompt &&subdir/arr_varchar2_udt.tps
@&&subdir/arr_varchar2_udt.tps
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
