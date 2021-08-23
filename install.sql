whenever sqlerror exit failure
--
-- You can comment this type creation if you already have one. Just
-- global search and replace within app_csv_udt.tps and app_csv_udt.tpb
-- for the string arr_varchar2_udt. get_rows may need a change to a local
-- variable to match the array member type if it is not VARCHAR2(4000).
--
CREATE OR REPLACE TYPE arr_varchar2_udt FORCE AS TABLE OF VARCHAR2(4000);
/
-- these settings are a personal preference. 
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
prompt app_csv_udt.tps
@app_csv_udt.tps
prompt app_csv_udt.tpb
@app_csv_udt.tpb
ALTER SESSION SET plsql_optimize_level=2;
ALTER SESSION SET plsql_code_type = INTERPRETED;
