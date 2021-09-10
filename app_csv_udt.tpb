CREATE OR REPLACE TYPE BODY app_csv_udt AS
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


    CONSTRUCTOR FUNCTION app_csv_udt(
        p_cursor                SYS_REFCURSOR
        ,p_separator            VARCHAR2 := ','
        ,p_quote_all_strings    VARCHAR2 := 'N'
        ,p_strip_separator      VARCHAR2 := 'N' -- strip comma from fields rather than quote
        ,p_bulk_count           INTEGER := 100
        ,p_num_format           VARCHAR2 := 'tm9'
        ,p_date_format          VARCHAR2 := 'MM/DD/YYYY'
        ,p_interval_format      VARCHAR2 := NULL
    ) RETURN SELF AS RESULT
    IS
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
        SELF.app_dbms_sql_str_constructor(
            p_cursor                => p_cursor
            ,p_bulk_count           => p_bulk_count
            ,p_default_num_fmt      => p_num_format
            ,p_default_date_fmt     => p_date_format
            ,p_default_interval_fmt => p_interval_format
        );
        separator := p_separator;
        quote_all_strings := CASE WHEN UPPER(p_quote_all_strings) LIKE 'Y%' THEN 'Y' ELSE 'N' END;
        strip_separator := CASE WHEN UPPER(p_strip_separator) LIKE 'Y%' THEN 'Y' ELSE 'N' END;

        -- although supertyp handles conversion to strings, we need to know if the original
        -- column was a string or not in order to honor the quote_all_strings directive
        csv_col_types := arr_varchar2_udt();
        csv_col_types.EXTEND(col_types.COUNT);
        FOR i in 1..col_types.COUNT
        LOOP
            csv_col_types(i) := lookup_col_type(col_types(i));
        END LOOP;
        RETURN;
    END;

    MEMBER PROCEDURE destructor
    IS
    BEGIN
        IF ctx IS NOT NULL THEN
            DBMS_SQL.close_cursor(ctx);
        END IF;
    END;

    MEMBER FUNCTION get_header_row RETURN CLOB
    IS
        v_str       CLOB; -- maxes at 4000 if calling table function from sql
        v_col_name  VARCHAR2(32767);
        v_a         arr_varchar2_udt;
    BEGIN
        v_a := SELF.get_column_names;
        FOR i IN 1..v_a.COUNT
        LOOP
            v_col_name := v_a(i);
            IF strip_separator = 'Y' THEN
                v_col_name := REPLACE(v_col_name, separator);
            ELSIF quote_all_strings = 'Y'
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

    MEMBER PROCEDURE get_next_row (
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_clob OUT NOCOPY  CLOB
    )
    IS
        v_col_val   CLOB;
        v_a         arr_clob_udt;

        FUNCTION quote_str(p_col BINARY_INTEGER) RETURN CLOB IS
            l_str   CLOB;
        BEGIN
            l_str := REPLACE(v_a(p_col), CASE WHEN strip_separator = 'Y' THEN separator END); -- null replacement string is noop

            IF (csv_col_types(p_col) = 'C' AND quote_all_strings = 'Y') THEN 
                -- preserve leading/trailing spaces too.
                l_str := '"'
                        ||REPLACE(l_str, '"', '""') -- double up dquotes inside field to *quote* them
                        ||'"'
                    ;
            ELSE
                l_str := TRIM(l_str); 
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
        SELF.get_next_column_values(v_a);
        IF v_a IS NOT NULL THEN
            p_clob := quote_str(1);
            FOR j IN 2..v_a.COUNT
            LOOP
                p_clob := p_clob||separator||quote_str(j);
            END LOOP;
        END IF;
    END;

    MEMBER PROCEDURE get_clob(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_clob OUT NOCOPY  CLOB
        ,p_do_header        VARCHAR2 := 'N'
        ,p_lf_only          BOOLEAN := TRUE
    ) 
    IS
        v_str   CLOB;
        v_crlf  VARCHAR2(2) := CASE WHEN p_lf_only THEN CHR(10) ELSE CHR(13)||CHR(10) END;
    BEGIN
        get_next_row(v_str);
        IF v_str IS NOT NULL THEN -- want to return NULL if no rows. Not a header
            p_clob := '';
            IF UPPER(p_do_header) LIKE 'Y%' THEN
                p_clob := get_header_row||v_crlf;
            END IF;
            LOOP
                p_clob := p_clob||v_str||v_crlf;
                get_next_row(v_str);
                EXIT WHEN v_str IS NULL;
            END LOOP;
        END IF;
    END;


    MEMBER PROCEDURE write_file(
        SELF IN OUT NOCOPY  app_csv_udt
        ,p_dir              VARCHAR2
        ,p_file_name        VARCHAR2
        ,p_do_header        VARCHAR2 := 'N'
    ) IS
        v_str               CLOB;
        v_file              UTL_FILE.file_type;
    BEGIN
        v_file := UTL_FILE.fopen(
            filename        => p_file_name
            ,location       => p_dir
            ,open_mode      => 'w'
            ,max_linesize   => 32767
        );
        get_next_row(v_str);
        IF v_str IS NOT NULL THEN -- we only want a header or any data written if we have rows
            IF UPPER(p_do_header) LIKE 'Y%' THEN
                UTL_FILE.put_line(v_file, get_header_row);
            END IF;

            LOOP
                UTL_FILE.put_line(v_file, v_str);
                get_next_row(v_str);
                EXIT WHEN v_str IS NULL;
            END LOOP;
        END IF;

        UTL_FILE.fclose(v_file);
    EXCEPTION WHEN OTHERS THEN
        IF UTL_FILE.is_open(v_file)
            THEN UTL_FILE.fclose(v_file);
        END IF;
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
        v_str               CLOB;
        v_app_csv           app_csv_udt;
    BEGIN
        v_app_csv := app_csv_udt(
            p_cursor                => p_cursor
            ,p_separator            => p_separator
            ,p_num_format           => p_num_format
            ,p_date_format          => p_date_format
            ,p_interval_format      => p_interval_format
            ,p_bulk_count           => p_bulk_count
            ,p_quote_all_strings    => p_quote_all_strings
        );
        v_app_csv.get_next_row(v_str);
        IF v_str IS NOT NULL THEN -- we only want a header or any data written if we have rows
            IF UPPER(p_do_header) LIKE 'Y%' THEN
                PIPE ROW(v_app_csv.get_header_row);
            END IF;

            LOOP
                -- if it is longer than 4000 chars I assume it will raise an exception
                PIPE ROW(v_str);
                v_app_csv.get_next_row(v_str);
                EXIT WHEN v_str IS NULL;
            END LOOP;
        END IF;
        RETURN;
    END;

END;
/
show errors
