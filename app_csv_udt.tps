CREATE OR REPLACE TYPE app_csv_udt AUTHID CURRENT_USER UNDER app_dbms_sql_str_udt (
-- https://github.com/lee-lindely/app_csv
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

     /*
     --from supertypes
     ctx                    INTEGER
    ,col_cnt                INTEGER
    ,bulk_cnt               INTEGER
    ,total_rows_fetched     INTEGER
    ,rows_fetched           INTEGER
    ,row_index              INTEGER
    ,col_types              arr_integer_udt
    ,default_num_fmt        VARCHAR2(4000)
    ,default_date_fmt       VARCHAR2(4000)
    ,default_interval_fmt   VARCHAR2(4000)
    ,arr_fmts               arr_varchar2_udt
    ,buf                    arr_arr_clob_udt

    MEMBER FUNCTION get_ctx            RETURN INTEGER
    MEMBER FUNCTION get_column_names   RETURN arr_varchar2_udt
    MEMBER FUNCTION get_column_types   RETURN arr_integer_udt
    MEMBER FUNCTION get_row_count RETURN INTEGER


    You also have this member procedure available to set TO_CHAR conversion formats
    on individual fields:
    MEMBER PROCEDURE set_fmt(
        ,p_col_index        BINARY_INTEGER
        ,p_fmt              VARCHAR2
    )

     */

     separator                  VARCHAR2(2)
    ,quote_all_strings          VARCHAR2(1)
    ,csv_col_types              arr_varchar2_udt
    --
    ,CONSTRUCTOR FUNCTION app_csv_udt(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_quote_all_strings    VARCHAR2 := 'N'
        ,p_bulk_count           INTEGER := 100
        -- you can set these to NULL if you want the default TO_CHAR conversions
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format      VARCHAR2 := NULL
        --
    ) RETURN SELF AS RESULT
    -- vestigal method that does nothing useful. It will close the cursor
    -- if you want to quit before fetching all rows
    ,MEMBER PROCEDURE   destructor
    --
    ,MEMBER PROCEDURE get_clob(
        SELF IN OUT NOCOPY      app_csv_udt
        ,p_clob OUT NOCOPY      CLOB
        ,p_do_header            VARCHAR2 := 'N'
        ,p_lf_only              BOOLEAN := TRUE
    ) 
    ,MEMBER PROCEDURE write_file(
        p_dir                   VARCHAR2
        ,p_file_name            VARCHAR2
        ,p_do_header            VARCHAR2 := 'N'
    )
    -- callable from SQL as SELECT * FROM TABLE(app_csv_udt.get_rows(CURSOR(...), ...))
    ,STATIC FUNCTION get_rows(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_do_header            VARCHAR2 := 'N'
        -- you can set these to NULL if you want the default TO_CHAR
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format      VARCHAR2 := NULL
        --
        ,p_bulk_count           INTEGER := 100
        ,p_quote_all_strings    VARCHAR2 := 'N'
    ) RETURN arr_varchar2_udt PIPELINED
    --
    -- If you are doing your own loop...
    --
    ,MEMBER FUNCTION    get_header_row RETURN CLOB

    ,MEMBER PROCEDURE   get_next_row (
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_clob OUT NOCOPY  CLOB
    ) 
);
/
show errors
