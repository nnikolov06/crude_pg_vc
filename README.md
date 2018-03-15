# crude_pg_vc
Crude pg structure vc

Usage: `pg_sync.bat <host> <port> <username> <password> <schema> <full_path_to_psql> <full_path_to_pg_dump> <vc_output_path>`

Supported objects:

**schemas**

**tables**

**foreign tables**

**functions**

**trigger functions**

**triggers**

**views**

**extensions**

**__foreign data wrappers__** - list only; no structure

**__foreign servers__** - list only; no structure

**__foreign data tables__** - list only; no structure


*vc_output_path* must be under version control.

*pg_sync* recursively deletes *schemas* from *vc_output_path*, dumps fresh object structures from the selected schema, commits the new changeset.
