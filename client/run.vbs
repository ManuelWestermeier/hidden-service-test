Set shellExecutor = CreateObject("WScript.Shell")
Set shellCopyer = CreateObject("WScript.Shell")
shellExecutor.Run "powershell -ExecutionPolicy Bypass -File ""./tor-executor.ps1""", 0, False
shellCopyer.Run "powershell -ExecutionPolicy Bypass -File ""./copyer.ps1""", 0, False