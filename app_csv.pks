CREATE OR REPLACE PACKAGE app_csv
AUTHID CURRENT_USER
IS

-- Credit is due William Robertson who wrote a similar package that I began using.
-- Ultimately I had needs it did not meet and wrote this replacement.
-- That is not a disparagment. He did good work and you might well prefer his package
-- which has additional features around header and trailer rows.
-- See http://www.williamrobertson.net/documents/refcursor-to-csv.shtml


/*
MIT License

Copyright (c) 2021 Lee Lindley

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

    -- A CSV row (can be any separator character, but comma or pipe are most common)
    -- will have the separator between each field, but not one after the last field (which
    -- would make it a delimited file rather than separated). If a field contains the separator
    -- character or newline, then the field value is enclosed in double quotes. In that case if the field 
    -- contains double quotes, then those are doubled up per RFC4180.
    -- https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml

    -- Methods in this package take a REF CURSOR as input and converts the result set into 
    -- CSV strings, optionally with a header. The end results can be:
    --  a) written to a file with OS specific line terminator (LF or CR/LF) between each string/row
    --  b) returned as a CLOB with CR/LF between each string/row (suitable for network transmission)
    --  c) returned as a TABLE (array) of strings via PIPE ROW (known as a TABLE function).
    --  d) Used in a PL/SQL loop, fetching new rows from the cursor as required to fill the buffer.
    --
    -- When complete, the number of rows processed can be retrieved from the package.


    -- can call after all fetches are done to get the row count not including any header row
    FUNCTION get_row_count  RETURN BINARY_INTEGER;

    -- Single call does everything and returns a clob with the CSV rows separated by CR/LF.
    -- If no rows are returned by the cursor, the optional header is not in the clob. The
    -- clob will be returned as NULL in that case.
    --
    -- DECLARE
    --     l_clob CLOB;
    --     l_src SYS_REFCURSOR;
    -- BEGIN
    --     OPEN l_src FOR SELECT * FROM hr.departments;
    --     l_clob := app_csv.get_clob(l_src, p_do_header => 'Y');
    --     .. insert the clob to a table, attach to an email, whatever.
    -- END;
    -- If you do the following:
    --      SELECT TABLE(app_csv.get_clob(CURSOR(SELECT * FROM hr.departments), p_do_header=>'Y')) FROM dual;
    -- Then in sqldeveloper you can double click the resulting column containing CLOB,
    -- click on the pencil icon and choose Download. Save as x.csv and open in excel.
    -- Toad has something similar.
    FUNCTION get_clob(
        p_src               SYS_REFCURSOR
        ,p_separator        VARCHAR2 := ','
        ,p_do_header        VARCHAR2 := 'N'
    ) RETURN CLOB;

    -- single call does everthing writing the CSV rows to the file separated by database
    -- OS default line terminator (LF or CR/LF).
    -- If no rows are returned by the cursor, the optional header is not written. File is
    -- created/replaced as empty.
    PROCEDURE write_file(
        p_src               SYS_REFCURSOR
        ,p_dir              VARCHAR2
        ,p_file_name        VARCHAR2
        ,p_separator        VARCHAR2 := ','
        ,p_do_header        VARCHAR2 := 'N'
    );


    -- callable from SQL as SELECT column_value FROM TABLE(app_csv.get_rows(CURSOR(select * from hr.departments), p_delimiter=>'|'));
    -- Returns the CSV strings (rows) as column named "COLUMN_VALUE"
    -- COLUMN_VALUE
    -- --------------------------------------------------------------------------------
    -- 230|IT Helpdesk||1700
    -- 240|Government Sales||1700
    -- 250|Retail Sales||1700
    -- 260|Recruiting||1700
    -- 270|Payroll||1700
    -- 
    -- 27 rows selected.
    FUNCTION get_rows(
        p_src               SYS_REFCURSOR
        ,p_separator        VARCHAR2 := ','
        ,p_do_header        VARCHAR2 := 'N'
    ) RETURN arr_varchar2_udt
    PIPELINED
    ;

    --
    -- If you want to do the looping yourself, call convert_cursor first. It sets everything up.
    -- Then call get_header_row and get_next_row as needed.
    -- You can look at the package body in procedure write_file and/or function get_clob for
    -- examples.
    --
    PROCEDURE convert_cursor(
        p_src               SYS_REFCURSOR
        ,p_separator        VARCHAR2 := ','
    );

    -- call this at any time after convert_cursor (but before the last row is fetched!)
    -- to get the header row in CSV format
    FUNCTION get_header_row RETURN VARCHAR2;

    -- call this in a loop until it returns NULL. Each call returns a record from the query
    -- converted into a CSV format string
    FUNCTION get_next_row   RETURN VARCHAR2;

END app_csv;
/
show errors
