whenever sqlerror exit failure
-- these settings are a personal preference. 
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
prompt app_csv_udt.tps
@app_csv_udt.tps
prompt app_csv_udt.tpb
@app_csv_udt.tpb
ALTER SESSION SET plsql_optimize_level=2;
ALTER SESSION SET plsql_code_type = INTERPRETED;
