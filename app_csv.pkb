CREATE OR REPLACE PACKAGE BODY app_csv
IS

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

    c_bulk_cnt     CONSTANT BINARY_INTEGER := 100;
    g_separator             VARCHAR2(2);            -- will be set by convert_cursor
    g_total_rows_fetched    BINARY_INTEGER := 0; 
    g_fetched_rows          BINARY_INTEGER := 0;    -- received on this bulk fetch call
    g_i                     BINARY_INTEGER := 0;    -- record number we are processing on this bulk fetch

    -- state variables maintaned between calls
    g_dbms_sql_ctx          INTEGER;                -- will have a value while we have an open cursor
    g_col_cnt               INTEGER;
    -- arrays holding cursor column attributes and column value buffers
    g_desc_tab              DBMS_SQL.desc_tab3;
    g_date_tab              DBMS_SQL.date_table;
    g_number_tab            DBMS_SQL.number_table;
    g_string_tab            DBMS_SQL.varchar2_table;


    -- 
    -- private methods
    --

    -- based on dbms_sql column info, get down to basic types that can be converted into
    FUNCTION lookup_col_type(p_col_type BINARY_INTEGER)
    RETURN VARCHAR2 -- D ate, N umber, C har
    IS
    BEGIN
        RETURN CASE WHEN p_col_type IN (1, 8, 9, 96, 112)
                    THEN 'C'
                    WHEN p_col_type IN (12, 178, 179, 180, 181 , 231)
                    THEN 'D'
                    WHEN p_col_type IN (2, 100, 101)
                    THEN 'N'
                    ELSE NULL
                END;
    END lookup_col_type;

    -- called repeatedly to refresh the buffer as needed until we run out of rows
    -- at which point it closes up shop.
    PROCEDURE fetch_rows
    IS
    BEGIN
        g_fetched_rows := DBMS_SQL.fetch_rows(g_dbms_sql_ctx);
        IF g_fetched_rows = 0 THEN
            DBMS_SQL.close_cursor(g_dbms_sql_ctx);
            g_dbms_sql_ctx := NULL;
            g_i := 0;
        ELSE
            g_total_rows_fetched := g_total_rows_fetched + g_fetched_rows;
        END IF;
    END fetch_rows;

    --
    -- end private methods
    --

    FUNCTION get_row_count RETURN BINARY_INTEGER
    IS
    BEGIN
        RETURN g_total_rows_fetched;
    END get_row_count;


    PROCEDURE convert_cursor(
        p_src           SYS_REFCURSOR
        ,p_separator    VARCHAR2 := ','
    ) IS
        v_src           SYS_REFCURSOR := p_src;
    BEGIN
        g_dbms_sql_ctx := DBMS_SQL.to_cursor_number(v_src);
        DBMS_SQL.describe_columns3(g_dbms_sql_ctx, g_col_cnt, g_desc_tab);
        -- define the arrays for holding the column values from each bulk fetch
        FOR i IN 1..g_col_cnt
        LOOP
            CASE lookup_col_type(g_desc_tab(i).col_type)
                WHEN 'N' THEN
                    DBMS_SQL.define_array(g_dbms_sql_ctx, i, g_number_tab,  c_bulk_cnt, 1);
                WHEN 'D' THEN
                    DBMS_SQL.define_array(g_dbms_sql_ctx, i, g_date_tab,    c_bulk_cnt, 1);
                WHEN 'C' THEN
                    DBMS_SQL.define_array(g_dbms_sql_ctx, i, g_string_tab,  c_bulk_cnt, 1);
                ELSE
                    NULL;
            END CASE;
        END LOOP;
        g_separator := p_separator;
        g_total_rows_fetched := 0;
        g_i := 0;
        g_fetched_rows := 0;
    END convert_cursor;


    FUNCTION get_header_row RETURN VARCHAR2
    IS
        v_str       VARCHAR2(32767); -- maxes at 4000 if calling table function from sql
        v_col_name  VARCHAR2(32767);
        v_separator VARCHAR2(2);
    BEGIN
        FOR i IN 1..g_col_cnt
        LOOP
            v_col_name := g_desc_tab(i).col_name;
            IF REGEXP_INSTR(v_col_name, '['||g_separator||chr(10)||']') > 0 -- contains separator or newline
                THEN v_col_name := '"'
                        ||REPLACE(v_col_name, '"', '""') -- double up dquotes inside field to *quote* them
                        ||'"'
                    ;
            END IF;
            v_str := v_str||v_separator||v_col_name;
            v_separator := g_separator;
        END LOOP;
        RETURN v_str;
    END get_header_row;


    FUNCTION get_next_row RETURN VARCHAR2
    IS
        v_str   VARCHAR2(32767); -- maxes at 4000 if calling table function from sql

        FUNCTION get_col_val(
            p_col BINARY_INTEGER -- column index starting at 1
        )
        RETURN VARCHAR2
        IS
            l_str VARCHAR2(32767);
        BEGIN
            CASE lookup_col_type(g_desc_tab(p_col).col_type)
                WHEN 'N' THEN
                    g_number_tab.DELETE;
                    DBMS_SQL.column_value(g_dbms_sql_ctx, p_col, g_number_tab);
                    l_str := TO_CHAR(g_number_tab( g_i + g_number_tab.FIRST()), 'tm9' );
                WHEN 'D' THEN
                    g_date_tab.DELETE;
                    DBMS_SQL.column_value(g_dbms_sql_ctx, p_col, g_date_tab);
                    l_str := TO_CHAR(g_date_tab( g_i + g_date_tab.FIRST()), 'MM/DD/YYYY');
                WHEN 'C' THEN
                    g_string_tab.DELETE;
                    DBMS_SQL.column_value(g_dbms_sql_ctx, p_col, g_string_tab);
                    l_str := g_string_tab(g_i + g_string_tab.FIRST());
                ELSE
                    NULL;
            END CASE;
            IF REGEXP_INSTR(l_str, '['||g_separator||chr(10)||']') > 0 -- contains separator or newline
                THEN l_str := '"'
                        ||REPLACE(l_str, '"', '""') -- double up dquotes inside field to *quote* them
                        ||'"'
                    ;
            END IF;
            RETURN l_str;
        END;
    -- start main function get_next_row body
    BEGIN
        IF g_i >= g_fetched_rows THEN
            fetch_rows;
            IF g_fetched_rows = 0 THEN
                RETURN NULL;
            END IF;
            g_i := 1;
        ELSE
            g_i := g_i + 1;
        END IF;

        -- get_col_val uses g_i
        v_str := get_col_val(1);
        FOR i IN 2..g_col_cnt
        LOOP
            v_str := v_str||g_separator||get_col_val(i);
        END LOOP;

        RETURN v_str;
    END get_next_row;


    FUNCTION get_clob(
        p_src               SYS_REFCURSOR
        ,p_separator        VARCHAR2 := ','
        ,p_do_header        VARCHAR2 := 'N'
    ) RETURN CLOB
    IS
        v_clob  CLOB;
        v_str   VARCHAR2(32767);
        c_crlf  CONSTANT VARCHAR2(2) := CHR(13)||CHR(10);
    BEGIN
        convert_cursor(p_src, p_separator);
        v_str := get_next_row;
        IF v_str IS NOT NULL THEN -- want to return NULL if no rows. Not a header
            IF UPPER(p_do_header) LIKE 'Y%' THEN
                v_clob := get_header_row||c_crlf;
            END IF;
            LOOP
                v_clob := v_clob||v_str||c_crlf;
                v_str := get_next_row;
                EXIT WHEN v_str IS NULL;
            END LOOP;
        END IF;
        RETURN v_clob;
    END get_clob;


    PROCEDURE write_file(
        p_src               SYS_REFCURSOR
        ,p_dir              VARCHAR2
        ,p_file_name        VARCHAR2
        ,p_separator        VARCHAR2 := ','
        ,p_do_header        VARCHAR2 := 'N'
    ) IS
        v_str               VARCHAR2(32767);
        v_file              UTL_FILE.file_type;
    BEGIN
        v_file := UTL_FILE.fopen(
            filename        => p_file_name
            ,location       => p_dir
            ,open_mode      => 'w'
            ,max_linesize   => 32767
        );
        convert_cursor(p_src, p_separator);
        v_str := get_next_row;
        IF v_str IS NOT NULL THEN -- we only want a header or any data written if we have rows
            IF UPPER(p_do_header) LIKE 'Y%' THEN
                UTL_FILE.put_line(v_file, get_header_row);
            END IF;

            LOOP
                UTL_FILE.put_line(v_file, v_str);
                v_str := get_next_row;
                EXIT WHEN v_str IS NULL;
            END LOOP;
        END IF;

        UTL_FILE.fclose(v_file);
    EXCEPTION WHEN OTHERS THEN
        UTL_FILE.fclose(v_file);
        RAISE;
    END write_file;


    FUNCTION get_rows(
        p_src               SYS_REFCURSOR
        ,p_separator        VARCHAR2 := ','
        ,p_do_header        VARCHAR2 := 'N'
    ) RETURN arr_varchar2_udt
    PIPELINED
    IS
        v_str               VARCHAR2(4000);
    BEGIN
        convert_cursor(p_src, p_separator);
        v_str := get_next_row;
        IF v_str IS NOT NULL THEN -- we only want a header or any data written if we have rows
            IF UPPER(p_do_header) LIKE 'Y%' THEN
                PIPE ROW(get_header_row);
            END IF;

            LOOP
                PIPE ROW(v_str);
                v_str := get_next_row;
                EXIT WHEN v_str IS NULL;
            END LOOP;
        END IF;
        RETURN;
    END get_rows;

END app_csv;
/
show errors
