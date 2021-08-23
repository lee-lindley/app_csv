
# app_csv - An Oracle PL/SQL CSV Record Generator

Create Comma Separated Value strings (rows) from an Oracle query. 

A CSV row (can be any separator character, but comma or pipe are most common)
will have the separator between each field, but not one after the last field (which
would make it a delimited file rather than separated). If a field contains the separator
character or newline, then the field value is enclosed in double quotes. In that case if the field 
contains double quotes, then those are doubled up 
per [RFC4180](https://www.loc.gov/preservation/digital/formats/fdd/fdd000323.shtml).

The resulting set of strings (rows) can be written to a file, collected in a CLOB or returned from 
a "TABLE" function in a SQL query via PIPE ROW.

# Installation

Clone this repository or download it as a [zip](https://github.com/lee-lindley/app_csv/archive/refs/heads/main.zip) archive.

Run [install.sql](#installsql) or compile the package header and body as you see fit.

If you already have a suitable TABLE type, you can globally replace the string *arr_varchar2_udt* in
the .pks and .pkb files and comment out the section that creates it in the install file. 

# Use Cases

## Create a CSV File

Produce a CSV file on the Oracle server in a directory to which you have write access. Presumably
you have a process that can then access the file, perhaps sending it to a vendor.

```sql
    DECLARE
        l_src   SYS_REFCURSOR;
    BEGIN
        OPEN l_src FOR SELECT * FROM hr.departments;
        app_csv.write_file(
            p_src           => l_src
            ,p_dir          => 'MY_DIR_NAME'
            ,p_file_name    => 'dept_listing.csv'
            ,p_do_header    => 'Y'
        );
        DBMS_OUTPUT.PUT_LINE('wrote '||TO_CHAR(app_csv.get_row_count)||' records to MY_DIR_NAME/dept_listing.csv');
    END;
```

## Retrieve a CLOB

The CSV strings can be concatenated into a CLOB with CR/LF between each row. The resulting CLOB can be
attached to an e-mail, written to a file or inserted/updated to a CLOB column in a table. Perhaps
added to a zip archive. There are many possibilites once you have the CSV content in a CLOB.

```sql
    DECLARE
        l_clob CLOB;
        l_src SYS_REFCURSOR;
    BEGIN
        OPEN l_src FOR SELECT * FROM hr.departments;
        l_clob := app_csv.get_clob(l_src, p_do_header => 'Y', p_separator => '|');
    END;
```

## Read from TABLE Function

You can use SQL directly to read CSV strings as records from the TABLE function *get_rows*, perhaps
spooling them to a text file with sqlplus.

```sql
    SELECT p.column_value
    FROM TABLE(app_csv.get_rows( 
                    CURSOR(SELECT * FROM hr.departments)
                    ,p_do_header => 'Y'
                    ,p_separator => '|' 
                                )
              ) p
    ;
```

## Process Results in a Loop

Although you could run a SELECT from the TABLE function *get_rows* in an implied cursor loop, 
you can also simply step through
the results the same way the preceding methods do. Perhaps you have a more involved use case such
as sending the resulting rows to multiple destinations, or creating a trailer record.

```sql
    DECLARE
        l_src   SYS_REFCURSOR;
        l_rec   VARCHAR2(32767);
        l_file  UTL_FILE.file_type;
    BEGIN
        OPEN l_src FOR SELECT * FROM hr.departments;
        app_csv.convert_cursor(l_src);
        l_rec := app_csv.get_next_row;
        IF l_rec IS NOT NULL THEN -- do not want to write anything unless we have data from the cursor
            l_file := UTL_FILE.fopen(
                filename        => 'my_file_name.csv'
                ,location       => 'MY_DIR'
                ,open_mode      => 'w'
                ,max_linesize   => 32767
            );
            UTL_FILE.put_line(l_file, get_header_row);
            LOOP
                UTL_FILE.put_line(l_file, l_rec);
                l_rec := get_next_row;
                EXIT WHEN l_rec IS NULL;
            END LOOP;
            UTL_FILE.put_line(l_file, '---RECORD COUNT: '||TO_CHAR(app_csv.get_row_count));
            UTL_FILE.fclose(v_file);
        END IF;
    END;
```
