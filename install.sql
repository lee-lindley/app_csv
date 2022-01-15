whenever sqlerror continue
prompt ok for drop to fail if type does not exist
drop type app_csv_udt;
prompt ok if drop failed for type does not exist
whenever sqlerror exit failure
set define on

-- for conditional compilation based on sqlplus define settings.
-- When we select a column alias named "file_choice", we get a sqlplus define value for "file_choice"
COLUMN file_choice NEW_VALUE do_file NOPRINT
--
-- name these any way you like. If you already have types that match these, give those names
-- and change the "compile" define value to FALSE
--
define d_arr_integer_udt="arr_integer_udt"
define compile_arr_integer_udt="TRUE"
define d_arr_varchar2_udt="arr_varchar2_udt"
define compile_arr_varchar2_udt="TRUE"
define d_arr_clob_udt="arr_clob_udt"
define compile_arr_clob_udt="TRUE"
define d_arr_arr_clob_udt="arr_arr_clob_udt"
define compile_arr_arr_clob_udt="TRUE"
-- if you already have app_dbms_sql compiled, set to false
define compile_app_dbms_sql="TRUE"
--
define subdir=plsql_utilities/app_types
SELECT DECODE('&&compile_arr_integer_udt','TRUE','&&subdir./arr_integer_udt.tps', 'do_nothing.sql arr_integer_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
SELECT DECODE('&&compile_arr_varchar2_udt','TRUE','&&subdir./arr_varchar2_udt.tps', 'do_nothing.sql arr_varchar2_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
SELECT DECODE('&&compile_arr_clob_udt','TRUE','&&subdir./arr_clob_udt.tps', 'do_nothing.sql arr_clob_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
SELECT DECODE('&&compile_arr_arr_clob_udt','TRUE','&&subdir./arr_arr_clob_udt.tps', 'do_nothing.sql arr_arr_clob_udt') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file

-- these settings are a personal preference. 
ALTER SESSION SET plsql_code_type = NATIVE;
ALTER SESSION SET plsql_optimize_level=3;
define subdir=plsql_utilities/app_dbms_sql
SELECT DECODE('&&compile_app_dbms_sql','TRUE','&&subdir./install_app_dbms_sql.sql', 'do_nothing.sql app_dbms_sql') AS file_choice FROM dual;
prompt calling &&do_file
@@&&do_file
--
prompt 
prompt app_csv_udt.tps
@@app_csv_udt.tps
prompt app_csv_udt.tpb
@@app_csv_udt.tpb
ALTER SESSION SET plsql_optimize_level=2;
ALTER SESSION SET plsql_code_type = INTERPRETED;
--
--prompt running compile_schema for invalid objects
--BEGIN
--    DBMS_UTILITY.compile_schema( schema => SYS_CONTEXT('userenv','current_schema')
--                                ,compile_all => FALSE
--                                ,reuse_settings => TRUE
--                            );
--END;
--/

