rem @echo off
setlocal EnableExtensions EnableDelayedExpansion
if "%~1"=="?" goto help
if "%~1"=="-?" goto help
if "%~1"=="--?" goto help
if "%~1"=="/?" goto help
if "%~1"=="h" goto help
if "%~1"=="-h" goto help
if "%~1"=="--h" goto help
if "%~1"=="/h" goto help
if "%~1"=="help" goto help
if "%~1"=="-help" goto help
if "%~1"=="--help" goto help
if "%~1"=="/help" goto help
if exist pg_sync.lock goto in_process
if "%~1"=="" goto no_params
if "%~2"=="" goto no_params
if "%~3"=="" goto no_params
if "%~4"=="" goto no_params
if "%~5"=="" goto no_params
if "%~6"=="" goto no_params
if "%~7"=="" goto no_params
if "%~8"=="" goto no_params
rem Create pg_sync.lock
echo %RANDOM% > pg_sync.lock || goto general_error
set v_host=%1
set v_port=%2
set v_user=%3
set v_password=%4
set v_dbname=%5
set v_psql=%6
set v_pgdump=%7
set v_outpath=%8
set v_update_time="%computername% | %username% | %date% | %time%"
set v_nothing_to_do=1
set v_revert=1
echo Working...
rem Output path
if not exist %v_outpath% md %v_outpath%
pushd %v_outpath%
if not exist .git git init && echo last_update.inf > .gitignore && echo db_tree.txt >> .gitignore && echo reference/* >> .gitignore
if %ERRORLEVEL% neq 0 goto general_error
if exist %v_dbname% xcopy %v_dbname% %v_dbname%_rev /I/S/Q/Y
if %ERRORLEVEL% neq 0 goto general_error
if exist %v_dbname% rd %v_dbname% /s/q ||goto general_error
md %v_dbname%
if %ERRORLEVEL% neq 0 goto general_error
pushd %v_dbname%

rem Extensions
if not exist extensions md extensions & pushd extensions
for /f "tokens=1* delims=[] " %%e in ('CALL %v_psql% -t -A -c "SELECT e.name FROM pg_catalog.pg_available_extensions e JOIN information_schema._pg_foreign_data_wrappers f ON e.name = f.foreign_data_wrapper_name;" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
	for /f "tokens=1* delims=[] " %%v in ('CALL %v_psql% -t -A -c "select v.version from pg_catalog.pg_available_extension_versions v where v.name = '%%e'" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
		echo EXTENSION=%%e
		D:\Dev\Srv\pgsql\bin\psql.exe -t -A -c "SELECT 'CREATE EXTENSION %%e '||E'\n'||'SCHEMA public '||E'\n'||'VERSION "%%v"'" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% > %%e.sql
		if %ERRORLEVEL% neq 0 goto general_error
	)
)
popd
if %ERRORLEVEL% neq 0 goto general_error

rem Foreign data wrappers
if not exist fdw md fdw & pushd fdw
if %ERRORLEVEL% neq 0 goto general_error
echo FOREIGN DATA WRAPPERS
echo Name^|Owner^|Handler^|Validator^|Access privileges^|FDW Options^|Description > FDW.txt || goto general_error
D:\Dev\Srv\pgsql\bin\psql.exe -t -A -c \dew[+] postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% >> FDW.txt || goto general_error
if %ERRORLEVEL% neq 0 goto general_error
echo "MANUAL CREATION ONLY" > WARNING.txt
popd

rem Foreign servers
if not exist fs md fs & pushd fs
if %ERRORLEVEL% neq 0 goto general_error
echo FOREIGN SERVERS
echo Name^|Owner^|Foreign data wrapper^|Access privileges^|Type^|Version^|FDW Options^|Description > FS.txt || goto general_error
D:\Dev\Srv\pgsql\bin\psql.exe -t -A -c \des[+] postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% >> FS.txt || goto general_error
if %ERRORLEVEL% neq 0 goto general_error
echo "MANUAL CREATION ONLY" > WARNING.txt
popd

rem Foreign data tables
if not exist ft md ft & pushd ft
if %ERRORLEVEL% neq 0 goto general_error
echo FOREIGN DATA TABLES
echo Foreign table schema^|Foreign table name^|Options^|Foreign server catalog^|Foreign server name^|Authorization identifier > FT.txt || goto general_error
D:\Dev\Srv\pgsql\bin\psql.exe -t -A -c "SELECT * FROM information_schema._pg_foreign_tables" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% >> FT.txt || goto general_error
if %ERRORLEVEL% neq 0 goto general_error
echo "MANUAL CREATION ONLY" > WARNING.txt
popd

md schemas
pushd schemas

for /f "tokens=1* delims=[] " %%s in ('CALL %v_psql% -t -A -c "SELECT DISTINCT ON(table_schema) table_schema FROM information_schema.tables WHERE table_schema not in ('pg_catalog', 'information_schema') AND table_schema not like 'pg_toast%%'" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
    
    set v_nothing_to_do=0
	set v_revert=0
    
    rem Schema
    md %%s & pushd %%s
	if %ERRORLEVEL% neq 0 goto general_error
    echo Schema=%%s
    echo CREATE SCHEMA %%s; > %%s.sql || goto general_error
	
    rem Tables
	if not exist tables md tables & pushd tables
    for /f "tokens=1* delims=[] " %%t in ('CALL %v_psql% -t -A -c "SELECT table_name FROM information_schema.tables WHERE table_type='BASE TABLE' AND table_schema='"%%s"';" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
        echo Table=%%t
        %v_pgdump% --dbname=postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% -s --table %%s.%%t > %%s.%%t.sql || goto general_error
		if %ERRORLEVEL% neq 0 goto general_error
    )
    popd

    rem Foreign tables
	if not exist foreigntables md foreigntables & pushd foreigntables
    for /f "tokens=1* delims=[] " %%t in ('CALL %v_psql% -t -A -c "SELECT table_name FROM information_schema.tables WHERE table_type='FOREIGN TABLE' AND table_schema='"%%s"';" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
		echo Foreign table=%%t
        %v_pgdump% --dbname=postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% -s --table %%s.%%t > %%s.%%t.sql || goto general_error
		if %ERRORLEVEL% neq 0 goto general_error
    )
    popd

    rem Functions(including trigger functions)
	if not exist functons md functions & pushd functions
    for /f "tokens=1* delims=[] " %%f in ('CALL %v_psql% -t -A -c "SELECT f.proname FROM pg_catalog.pg_proc f INNER JOIN pg_catalog.pg_namespace n ON (f.pronamespace = n.oid) WHERE n.nspname = '%%s';" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
        echo Function=%%f
        %v_psql% -t -A -c "SELECT pg_get_functiondef(f.oid) FROM pg_catalog.pg_proc f INNER JOIN pg_catalog.pg_namespace n ON (f.pronamespace = n.oid) WHERE f.proname = '"%%f"';" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% > %%s.%%f.sql || goto general_error
		if %ERRORLEVEL% neq 0 goto general_error
    )
    popd

    rem Triggers
	if not exist triggers md triggers & pushd triggers
    for /f "tokens=1* delims=[] " %%t in ('CALL %v_psql% -t -A -c "SELECT DISTINCT ON (trigger_name) trigger_name  FROM information_schema.triggers WHERE trigger_schema='%%s';" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
        echo Trigger=%%t
        %v_psql% -t -A -c "SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE tgname = '"%%t"';" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% > %%s.%%t.sql || goto general_error
		if %ERRORLEVEL% neq 0 goto general_error
    )
    popd

    rem Views
	if not exist views md views & pushd views
    for /f "tokens=1* delims=[] " %%v in ('CALL %v_psql% -t -A -c "SELECT viewname FROM pg_views WHERE schemaname = '"%%s"';" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname%') do (
        echo View=%%v
        %v_psql% -t -A -c "SELECT 'CREATE OR REPLACE VIEW "%%s.%%v" AS '||E'\n'||pg_get_viewdef('"%%v"', true);" postgresql://%v_user%:%v_password%@%v_host%:%v_port%/%v_dbname% > %%s.%%v.sql || goto general_error
		if %ERRORLEVEL% neq 0 goto general_error
    )
    popd

    popd
)
popd
popd
if %v_revert% equ 1 xcopy %v_dbname%_rev %v_dbname% /I/S/Q/Y
if %ERRORLEVEL% neq 0 goto general_error
rd %v_dbname%_rev /s/q
if %ERRORLEVEL% neq 0 goto general_error
tree /f /a > db_tree.txt
popd
del pg_sync.lock
if %ERRORLEVEL% neq 0 goto general_error
if %v_nothing_to_do% equ 1 goto general_error 
rem Commit
pushd %v_outpath%
git add .
if %ERRORLEVEL% neq 0 goto general_error
echo Added changes
git commit -m %v_update_time%
echo Commited changes
for /F "tokens=*" %%F in ('git log --format^="%%H" -n 1') do (
set v_commit_hash=%%F
)
set v_line='%v_commit_hash% - %v_update_time%'
echo %v_line% > last_update.inf
if not exist reference md reference
pushd reference
ipconfig /all > %v_commit_hash%.inf
popd
popd
echo Done.
exit /B 0

:in_process
echo Process is running. Try again later.
exit /B 1

:no_params
echo Some or all arguments missing.
echo Usage: pg_sync.bat host port username password database "full_path_to_psql" "full_path_to_pg_dump" vc_output_path
exit /B 2

:general_error
echo General error.
echo %ERRORLEVEL%
if exist pg_sync.lock del pg_sync.lock
exit /B 3

:help
echo Usage: pg_sync.bat host port username password database "full_path_to_psql" "full_path_to_pg_dump" vc_output_path
echo.
echo  - full_path_to_psql and full_path_to_pg_dum must always be enclosed in double quotes for safety.
echo  - vc_output_path may or may not be enlcosed in double quotes depending on wheteher there are spaces in the path. 
echo  - vc_output_path will be created if it does not exist.
echo  - An empty repository will be created in vc_output_path if one does not exist.
echo  - Path to Git must exist in system path.
exit /B 0