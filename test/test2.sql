CREATE OR REPLACE FUNCTION app_csv_test2 RETURN CLOB
AS
    v_csv   app_csv_udt;
    v_src   SYS_REFCURSOR;
    v_clob  CLOB;
BEGIN
    OPEN v_src FOR SELECT * FROM hr.departments ORDER BY department_name;
    v_csv := app_csv_udt(
        p_cursor        => v_src
        ,p_num_format  => '099999'
    );
    BEGIN
        v_clob := v_csv.get_clob(p_do_header => 'Y');
    EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.put_line(sqlerrm);
        RAISE;
    END;
    v_csv.destructor;
    RETURN v_clob;
END;
/
show errors
set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
set long 90000
set serveroutput on
spool test2.csv
SELECT app_csv_test2 FROM dual
;
spool off
DROP FUNCTION app_csv_test2;
