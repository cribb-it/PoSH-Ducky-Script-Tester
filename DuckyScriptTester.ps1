##################################################
#                DuckyScriptTester
##################################################
# Author:      Cribbit
# Version:     1.0 
# Tested on:   Windows 10 21H1 (Powershell 5.1)
# Notes:       This is a very basic tester it does not support all of the ducky script language


######################Config######################

# Path to ducky script (Not the encoded bin file)
$path=".\ds.txt"

##################################################

[system.reflection.assembly]::Loadwithpartialname("system.windows.forms")

$wshell = New-Object -ComObject wscript.shell

Add-Type @"
using System;                                                                     
using System.Runtime.InteropServices;
public class KBd {
[DllImport("user32.dll")]                                                            
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);}
"@   


function Hold-Key {
    param (
        $raw
    )
	[KBd]::keybd_event($raw, 0x45, 0, 0);
}

function Release-Key {
    param (
        $raw
    )
	[KBd]::keybd_event($raw, 0x45, 0x2, 0); 
}

#https://docs.microsoft.com/en-us/dotnet/api/system.windows.forms.keys?view=windowsdesktop-6.0
function Convert-toFormsKey {
    param (
        [string]$raw
    )
	switch ( $raw )
	{
        {$PSItem -match '(WINDOWS|GUI)'}
		{
			Write-Output ([int]([System.Windows.Forms.Keys]::LWin))
            continue
		}
        {$PSItem -match '(CONTROL|CTRL)'}
		{
			Write-Output ([int]([System.Windows.Forms.Keys]::LControlKey)) 
            continue
		}
        SHIFT
		{
			Write-Output ([int]([System.Windows.Forms.Keys]::LShiftKey))
            continue
		}
        ALT
		{
			Write-Output ([int]([System.Windows.Forms.Keys]::Menu))
            continue
		}
        default 
        {
            Write-Output ([int]([System.Windows.Forms.Keys]::None))
        }
	}    
}

function Convert-toShellKey {
    param (
        [string]$raw
    )
	#https://ss64.com/vb/sendkeys.html
    $raw=($raw -replace "ESC","ESCAPE" -replace "SPACE", " " -replace "PRINTSCREEN", "PRTSC" -replace "PAGEUP", "PGUP" -replace "PAGEDOWN", "PGDN" -replace "ARROW", "")
    Write-Output "{$raw}"
}

Clear

sleep -Milliseconds 500

gc $path | % {
    $line=$_
    $pos = $_.IndexOf(" ")
    $command = if ($pos -gt 0) {$line.Substring(0, $pos)} Else {$line}
    $params = $line.Substring($pos+1)
    switch ( $command )
    {
        DELAY
        {
            if ($pos -gt 0) {
                sleep -Milliseconds $params
            }
            continue
        }
        STRING
        {
            $params = ($params -replace "{","OPENBRACKET" -replace "}","{}}" -replace "OPENBRACKET", "{{}" -replace "~","{~}" -replace "!","{!}" -replace "\^","{\^}" -replace "\+","{\+}" -replace "%","{%}")
            $wshell.SendKeys($params)
            continue
        }
        {$PSItem -match '^(WINDOWS|GUI|CONTROL|CTRL|ALT|SHIFT).*'}
        {
			$stringArray =$command.Split("-")
			$stringArray | % { Hold-Key (Convert-toFormsKey $_) }
			if ($pos -gt 0)
			{
				if ($params.length -gt 1)
				{
					$wshell.SendKeys((Convert-toShellKey $params))
				}
				else
				{
					$wshell.SendKeys($params)
				}
			}
			$stringArray | % { Release-Key (Convert-toFormsKey $_) }
            continue
        }
        {$PSItem -notmatch 'REM' -and $pos -lt 0}
        { 
            $wshell.SendKeys((Convert-toShellKey $command))
            continue
        }
    }
}