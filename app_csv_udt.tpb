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


    MEMBER FUNCTION get_row_count RETURN BINARY_INTEGER
    IS
    BEGIN
        RETURN app_dbms_sql.get_row_count(ctx);
    END;


    CONSTRUCTOR FUNCTION app_csv_udt(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format      VARCHAR2 := NULL
        ,p_bulk_count           INTEGER := 100
        ,p_quote_all_strings    VARCHAR2 := 'N'
    ) RETURN SELF AS RESULT
    IS
        v_desc_tab3             DBMS_SQL.desc_tab3;
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
        separator := p_separator;
        num_format := p_num_format;
        date_format := p_date_format;
        quote_all_strings := CASE WHEN UPPER(p_quote_all_strings) LIKE 'Y%' THEN 'Y' ELSE 'N' END;

        ctx := app_dbms_sql.convert_cursor(p_cursor => p_cursor, p_bulk_count => p_bulk_count);

        -- although app_dbms_sql handles conversion to strings, we need to know if the original
        -- column was a string or not in order to honor the quote_all_strings directive
        v_desc_tab3 := app_dbms_sql.get_desc_tab3(ctx);
        col_types := arr_varchar2_udt();
        col_types.EXTEND(v_desc_tab3.COUNT);
        FOR i in 1..v_desc_tab3.COUNT
        LOOP
            col_types(i) := lookup_col_type(v_desc_tab3(i).col_type);
        END LOOP;
        RETURN;
    EXCEPTION WHEN OTHERS THEN
        app_dbms_sql.close_cursor(ctx);
        ctx := NULL;
        RAISE;
    END;

    -- clears out the context in the hash in package global memory of app_dbms_sql as well
    -- as dbms_sql. 
    MEMBER PROCEDURE destructor
    IS
    BEGIN
        app_dbms_sql.close_cursor(ctx);
        ctx := NULL;
    END;

    MEMBER PROCEDURE   set_date_format(
        p_date_format       VARCHAR2
    ) IS
    BEGIN
        date_format := p_date_format;
    END;

    MEMBER PROCEDURE   set_num_format(
        p_num_format        VARCHAR2
    ) IS
    BEGIN
        num_format := p_num_format;
    END;

    MEMBER PROCEDURE   set_separator(
        p_separator         VARCHAR2
    ) IS
    BEGIN
        separator := p_separator;
    END;

    MEMBER FUNCTION get_header_row RETURN VARCHAR2
    IS
        v_str       VARCHAR2(32767); -- maxes at 4000 if calling table function from sql
        v_col_name  VARCHAR2(32767);
        v_a         app_dbms_sql.t_arr_varchar2;
    BEGIN
        v_a := app_dbms_sql.get_column_names(ctx);
        FOR i IN 1..v_a.COUNT
        LOOP
            v_col_name := v_a(i);
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

    MEMBER FUNCTION get_next_row (
        SELF IN OUT NOCOPY  app_csv_udt
    )
    RETURN VARCHAR2
    IS
        v_str       VARCHAR2(32767); -- maxes at 4000 if calling table function from sql
        v_col_val   VARCHAR2(32767);
        v_a         app_dbms_sql.t_arr_varchar2;

        FUNCTION quote_str(p_col BINARY_INTEGER) RETURN VARCHAR2 IS
            l_str   VARCHAR2(32767);
        BEGIN
            IF (col_types(p_col) = 'C' AND quote_all_strings = 'Y') THEN 
                -- preserve leading/trailing spaces too.
                l_str := '"'
                        ||REPLACE(v_a(p_col), '"', '""') -- double up dquotes inside field to *quote* them
                        ||'"'
                    ;
            ELSE
                l_str := TRIM(v_a(p_col)); 
                IF REGEXP_INSTR(l_str, '['||separator||chr(10)||']') > 0 THEN -- contains separator or newline
                    l_str := '"'
                        ||REPLACE(l_str, '"', '""') -- double up dquotes inside field to *quote* them
                        ||'"'
                    ;
                END IF;
            END IF;
            RETURN l_str;
        END;

    BEGIN
        v_a := app_dbms_sql.get_next_column_values(
            p_ctx               => ctx
            ,p_num_format       => num_format
            ,p_date_format      => date_format
            ,p_interval_format  => interval_format
        );
        IF v_a IS NOT NULL THEN
            v_str := quote_str(1);
            FOR j IN 2..v_a.COUNT
            LOOP
                v_str := v_str||separator||quote_str(j);
            END LOOP;
        END IF;
        RETURN v_str; -- will be null when all done
    EXCEPTION WHEN OTHERS THEN
        destructor;
        RAISE;
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
    EXCEPTION WHEN OTHERS THEN
        destructor;
        RAISE;
    END;


    MEMBER PROCEDURE write_file(
        p_dir               VARCHAR2
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
        destructor;
        UTL_FILE.fclose(v_file);
        RAISE;
    END;


    STATIC FUNCTION get_rows(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_do_header            VARCHAR2 := 'N'
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format      VARCHAR2 := NULL
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
        v_app_csv.destructor;
        RETURN;
    EXCEPTION WHEN OTHERS THEN
        v_app_csv.destructor;
        RAISE;
    END;

END;
/
show errors
