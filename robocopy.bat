@echo off
set source=%1
set dest=%2
xcopy /s /y %source% %dest%
del /s /q %source%
rmdir /s /q %source%
