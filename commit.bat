echo off
setlocal EnableExtensions EnableDelayedExpansion
set v_commit_msg=%1
set v_path=%2
pushd %v_path%
git add .
echo Added changes
git commit -m %v_commit_msg%
echo Commited changes
for /F "tokens=*" %%F in ('git log --format^="%%H" -n 1') do (
set var=%%F
)
set line='%var% - %v_commit_msg%'
echo %line% > last_update.inf
if not exist reference md reference
pushd reference
ipconfig > %var%.inf
popd
popd
