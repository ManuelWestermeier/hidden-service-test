Set shell = CreateObject("WScript.Shell")
shell.Run "powershell -ExecutionPolicy Bypass -File ""%~dp0tor-executor.ps1""", 0, False
