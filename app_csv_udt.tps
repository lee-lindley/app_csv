CREATE OR REPLACE TYPE app_csv_udt AUTHID CURRENT_USER AS OBJECT (

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

    bulk_cnt                    INTEGER 
    ,ctx                        INTEGER                 -- dbms_sql context
    ,separator                  VARCHAR2(2)
    ,num_format                 VARCHAR2(30)
    ,date_format                VARCHAR2(30)
    ,quote_all_strings          VARCHAR2(1)
    ,total_rows_fetched         INTEGER 
    ,fetched_rows               INTEGER
    ,row_index                  INTEGER
    ,col_cnt                    INTEGER
    ,col_names                  arr_varchar2_udt
    ,col_types                  arr_varchar2_udt
    --
    ,CONSTRUCTOR FUNCTION app_csv_udt(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_bulk_count           INTEGER := 100
        ,p_quote_all_strings    VARCHAR2 := 'N'
    ) RETURN SELF AS RESULT
    -- call this AFTER getting all the rows. Intermediate value is number of rows fetched
    ,MEMBER FUNCTION    get_row_count(
        SELF IN OUT NOCOPY  app_csv_udt
    ) RETURN INTEGER
    ,MEMBER FUNCTION get_clob(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_do_header            VARCHAR2 := 'N'
    ) RETURN CLOB
    ,MEMBER PROCEDURE write_file(
        SELF IN OUT NOCOPY      app_csv_udt
        ,p_dir                  VARCHAR2
        ,p_file_name            VARCHAR2
        ,p_do_header            VARCHAR2 := 'N'
    )
    -- callable from SQL as SELECT * FROM TABLE(app_csv_udt.get_rows(CURSOR(...), ...))
    ,STATIC FUNCTION get_rows(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_do_header            VARCHAR2 := 'N'
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_bulk_count           INTEGER := 100
        ,p_quote_all_strings    VARCHAR2 := 'N'
    ) RETURN arr_varchar2_udt PIPELINED
    --
    -- If you are doing your own loop...
    --
    ,MEMBER FUNCTION    get_header_row(
        SELF IN OUT NOCOPY  app_csv_udt
    ) RETURN VARCHAR2
    ,MEMBER FUNCTION    get_next_row(
        SELF IN OUT NOCOPY  app_csv_udt
    ) RETURN VARCHAR2
    -- unlikely, but maybe you do not know what these should be when you call the constructor
    ,MEMBER PROCEDURE   set_separator(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_separator        VARCHAR2
    )
    ,MEMBER PROCEDURE   set_date_format(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_date_format      VARCHAR2
    )
    ,MEMBER PROCEDURE   set_num_format(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_num_format       VARCHAR2
    )
);
/
show errors
