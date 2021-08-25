set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
set serveroutput on
spool test4.csv
WITH a AS (
    SELECT TO_CHAR(employee_id) AS "Emp ID", last_name||', '||first_name AS "Fname", hire_date AS "Date,Hire,YYYYMMDD", salary AS "Salary"
    FROM hr.employees
  UNION ALL
    SELECT '999' AS "Emp ID", '  Baggins, Bilbo "badboy" ' AS "Fname", TO_DATE('19991231','YYYYMMDD') AS "Date,Hire,YYYYMMDD", 123.45 AS "Salary"
    FROM dual
), b AS (
    SELECT * from a ORDER BY "Fname"
) SELECT column_value FROM TABLE(app_csv_udt.get_rows(
                                    p_cursor            => CURSOR(SELECT * FROM b)
                                    ,p_do_header        => 'Y'
                                    ,p_num_format       => '$999999.99'
                                    ,p_quote_all_strings=> 'Y'
                                                     )
                                )
;
spool off
