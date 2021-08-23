whenever sqlerror exit failure
CREATE OR REPLACE TYPE arr_varchar2_udt FORCE AS TABLE OF VARCHAR2(4000);
/
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
prompt app_csv.pks
@app_csv.pks
prompt app_csv.pkb
@app_csv.pkb
ALTER SESSION SET plsql_optimize_level=2;
ALTER SESSION SET plsql_code_type = INTERPRETED;
