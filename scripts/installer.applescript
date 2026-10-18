-- Finder runs this installer without opening Terminal.
on run
    try
        set resourceDirectory to POSIX path of (path to resource "install-app.sh")
        set appPayload to POSIX path of (path to resource "Clipboard Assistant.app")
        do shell script "/bin/zsh " & quoted form of resourceDirectory & " " & quoted form of appPayload
    on error errorMessage
        display alert "Clipboard Assistant could not be installed" message errorMessage as critical
    end try
end run
