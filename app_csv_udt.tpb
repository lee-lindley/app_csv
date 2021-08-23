CREATE OR REPLACE TYPE BODY app_csv_udt AS
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


    MEMBER FUNCTION get_row_count(
        SELF IN OUT NOCOPY  app_csv_udt
    ) RETURN INTEGER
    IS
    BEGIN
        RETURN total_rows_fetched;
    END;


    CONSTRUCTOR FUNCTION app_csv_udt(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_bulk_count           INTEGER := 100
        ,p_quote_all_strings    VARCHAR2 := 'N'
    ) RETURN SELF AS RESULT
    IS
        v_src               SYS_REFCURSOR := p_cursor;
        v_desc_tab          DBMS_SQL.desc_tab3;
        v_number_tab        DBMS_SQL.number_table;
        v_date_tab          DBMS_SQL.date_table;
        v_string_tab        DBMS_SQL.varchar2_table;

        -- based on dbms_sql column info, get down to basic types that can be converted into
        FUNCTION lookup_col_type(p_col_type INTEGER)
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
        END;
    BEGIN
        bulk_cnt := p_bulk_count;
        separator := p_separator;
        num_format := p_num_format;
        date_format := p_date_format;
        quote_all_strings := CASE WHEN UPPER(p_quote_all_strings) LIKE 'Y%' THEN 'Y' ELSE 'N' END;
        total_rows_fetched := 0;
        row_index := 0;
        fetched_rows := 0;

        ctx := DBMS_SQL.to_cursor_number(v_src);
        DBMS_SQL.describe_columns3(ctx, col_cnt, v_desc_tab);

        col_names := arr_varchar2_udt();
        col_names.EXTEND(col_cnt);
        col_types := arr_varchar2_udt();
        col_types.EXTEND(col_cnt);
        -- define the arrays for holding the column values from each bulk fetch
        FOR i IN 1..col_cnt
        LOOP
            col_names(i) := v_desc_tab(i).col_name;
            col_types(i) := lookup_col_type(v_desc_tab(i).col_type);
            CASE col_types(i)
                WHEN 'N' THEN
                    DBMS_SQL.define_array(ctx, i, v_number_tab,  bulk_cnt, 1);
                WHEN 'D' THEN
                    DBMS_SQL.define_array(ctx, i, v_date_tab,    bulk_cnt, 1);
                WHEN 'C' THEN
                    DBMS_SQL.define_array(ctx, i, v_string_tab,  bulk_cnt, 1);
                ELSE
                    NULL;
            END CASE;
        END LOOP;
        RETURN;
    END;

    MEMBER PROCEDURE   set_date_format(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_date_format      VARCHAR2
    ) IS
    BEGIN
        date_format := p_date_format;
    END;

    MEMBER PROCEDURE   set_num_format(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_num_format       VARCHAR2
    ) IS
    BEGIN
        num_format := p_num_format;
    END;
    MEMBER PROCEDURE   set_separator(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_separator        VARCHAR2
    ) IS
    BEGIN
        separator := p_separator;
    END;

    MEMBER FUNCTION get_header_row (
        SELF IN OUT NOCOPY  app_csv_udt
    ) RETURN VARCHAR2
    IS
        v_str       VARCHAR2(32767); -- maxes at 4000 if calling table function from sql
        v_col_name  VARCHAR2(32767);
    BEGIN
        FOR i IN 1..col_cnt
        LOOP
            v_col_name := col_names(i);
            IF quote_all_strings = 'Y'
                OR REGEXP_INSTR(v_col_name, '['||separator||chr(10)||']') > 0 -- contains separator or newline
                THEN v_col_name := '"'
                        ||REPLACE(v_col_name, '"', '""') -- double up dquotes inside field to *quote* them
                        ||'"'
                    ;
            END IF;
            v_str := v_str||CASE WHEN i > 1 THEN separator END||v_col_name;
        END LOOP;
        RETURN v_str;
    END;


    MEMBER FUNCTION get_next_row(
        SELF IN OUT NOCOPY  app_csv_udt
    ) RETURN VARCHAR2
    IS
        v_str   VARCHAR2(32767); -- maxes at 4000 if calling table function from sql
        v_date_tab      DBMS_SQL.date_table;
        v_number_tab    DBMS_SQL.number_table;
        v_string_tab    DBMS_SQL.varchar2_table;

        FUNCTION get_col_val(
            p_col INTEGER -- column index starting at 1
        )
        RETURN VARCHAR2
        IS
            l_str           VARCHAR2(32767);
        BEGIN
            CASE col_types(p_col)
                WHEN 'N' THEN
                    v_number_tab.DELETE;
                    DBMS_SQL.column_value(ctx, p_col, v_number_tab);
                    l_str := LTRIM(TO_CHAR(v_number_tab( row_index + v_number_tab.FIRST() - 1), num_format));
                WHEN 'D' THEN
                    v_date_tab.DELETE;
                    DBMS_SQL.column_value(ctx, p_col, v_date_tab);
                    l_str := TO_CHAR(v_date_tab( row_index + v_date_tab.FIRST() - 1), date_format);
                WHEN 'C' THEN
                    v_string_tab.DELETE;
                    DBMS_SQL.column_value(ctx, p_col, v_string_tab);
                    l_str := v_string_tab(row_index + v_string_tab.FIRST() - 1);
                ELSE
                    NULL;
            END CASE;
            IF (col_types(p_col) = 'C' AND quote_all_strings = 'Y')
                OR REGEXP_INSTR(l_str, '['||separator||chr(10)||']') > 0 -- contains separator or newline
                THEN l_str := '"'
                        ||REPLACE(l_str, '"', '""') -- double up dquotes inside field to *quote* them
                        ||'"'
                    ;
            END IF;
            RETURN l_str;
        END;

        -- called repeatedly to refresh the buffer as needed until we run out of rows
        -- at which point it closes up shop.
        PROCEDURE fetch_rows 
        IS
        BEGIN
            fetched_rows := DBMS_SQL.fetch_rows(ctx);
            IF fetched_rows = 0 THEN
                ctx := NULL;
                row_index := 0;
                DBMS_SQL.close_cursor(ctx);
            ELSE
                total_rows_fetched := total_rows_fetched + fetched_rows;
                row_index := 1;
            END IF;
        END;
    -- start main function get_next_row body
    BEGIN
        IF row_index >= fetched_rows THEN
            IF fetched_rows != bulk_cnt 
                AND fetched_rows != 0  -- initial state
            THEN
                -- the last call returned less than requested rows so we are done
                row_index := 0;
                DBMS_SQL.close_cursor(ctx);
                ctx := NULL;
                RETURN NULL;
            END IF;
            fetch_rows;
            IF fetched_rows = 0 THEN
                RETURN NULL;
            END IF;
            --row_index := 1;
        ELSE
            row_index := row_index + 1;
        END IF;

        v_str := get_col_val(1);
        FOR j IN 2..col_cnt
        LOOP
            v_str := v_str||separator||get_col_val(j);
        END LOOP;
        RETURN v_str;
    END;


    MEMBER FUNCTION get_clob(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_do_header        VARCHAR2 := 'N'
    ) RETURN CLOB
    IS
        v_clob  CLOB;
        v_str   VARCHAR2(32767);
        c_crlf  CONSTANT VARCHAR2(2) := CHR(13)||CHR(10);
    BEGIN
        v_str := get_next_row;
        IF v_str IS NOT NULL THEN -- want to return NULL if no rows. Not a header
            v_clob := '';
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
    END;


    MEMBER PROCEDURE write_file(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_dir              VARCHAR2
        ,p_file_name        VARCHAR2
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
    END;


    STATIC FUNCTION get_rows(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_do_header            VARCHAR2 := 'N'
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_bulk_count           INTEGER := 100
        ,p_quote_all_strings    VARCHAR2 := 'N'
    ) RETURN arr_varchar2_udt
    PIPELINED
    IS
        v_str               VARCHAR2(4000);
        v_app_csv           app_csv_udt;
    BEGIN
        v_app_csv := app_csv_udt(
            p_cursor                => p_cursor
            ,p_separator            => p_separator
            ,p_num_format           => p_num_format
            ,p_date_format          => p_date_format
            ,p_bulk_count           => p_bulk_count
            ,p_quote_all_strings    => p_quote_all_strings
        );
        v_str := v_app_csv.get_next_row;
        IF v_str IS NOT NULL THEN -- we only want a header or any data written if we have rows
            IF UPPER(p_do_header) LIKE 'Y%' THEN
                PIPE ROW(v_app_csv.get_header_row);
            END IF;

            LOOP
                PIPE ROW(v_str);
                v_str := v_app_csv.get_next_row;
                EXIT WHEN v_str IS NULL;
            END LOOP;
        END IF;
        RETURN;
    END;

END;
/
show errors
