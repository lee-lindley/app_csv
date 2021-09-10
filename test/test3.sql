DECLARE
    v_src   SYS_REFCURSOR;
    v_csv   app_csv_udt;
BEGIN
    OPEN v_src FOR SELECT * FROM (
        SELECT TO_CHAR(employee_id) AS "Emp ID", last_name||', '||first_name AS "Fname", hire_date AS "Date,Hire,YYYYMMDD", salary AS "Salary"
        from hr.employees
        UNION ALL
        SELECT '999' AS "Emp ID", '  Baggins, Bilbo "badboy" ' AS "Fname", TO_DATE('19991231','YYYYMMDD') AS "Date,Hire,YYYYMMDD", 123.45 AS "Salary"
        FROM dual
      ) ORDER BY LTRIM("Fname") ;
    v_csv := app_csv_udt(
        p_cursor        => v_src
        ,p_num_format   => '$999,999.99'
        ,p_date_format  => 'YYYYMMDD'
    );
    v_csv.write_file(p_dir => 'TMP_DIR', p_file_name => 'x.csv', p_do_header => 'Y');
END;
/
set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
set long 90000
set serveroutput on
spool test3.csv
SELECT TO_CLOB(BFILENAME('TMP_DIR','x.csv')) FROM dual
;
spool off
