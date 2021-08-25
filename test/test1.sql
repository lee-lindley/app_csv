set echo off
set linesize 200
set pagesize 0
set heading off
set trimspool on
set feedback off
spool test1.txt
SELECT a.column_value FROM TABLE(
        app_csv_udt.get_rows(CURSOR(SELECT * FROM hr.departments ORDER BY department_name)
                             ,p_separator=> '|'
                             ,p_do_header => 'Y'
                            )
    ) a
;
spool off
