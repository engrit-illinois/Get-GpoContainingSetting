# Summary
Searches matching GPOs in the given domain for those with XML matching a given string.

# Requirements
- Requires Powershell 7+, due to using the `ForEach-Object -Parallel` functionality.

# Usage
1. Download `Get-GpoContainingSetting.psm1` to the appropriate subdirectory of your PowerShell [modules directory](https://github.com/engrit-illinois/how-to-install-a-custom-powershell-module).
2. Run it using the examples and parameter documentation below.

# Examples
Search XML of all GPOs named like `"ENGR*"` for the string `"*engr-service-account*"`:
```powershell
Get-GpoContainingSetting -SettingQuery "*engr-service-account*" -GpoNameQuery "ENGR*"
```

# Parameters

### -SettingQuery \<string\>
Required string.  
The wildcard query to search for in each GPO's XML.  

### -GpoNameQuery \<string\>
Optional string.  
The wildcard query used to filter all retrieved GPOs before searching through their XML.  
Default is `"*"` (i.e. all GPOs in the domain).  

### -Domain \<string\>
Optional string.  
The domain from which to pull GPOs.  
Default is `"ad.uillinois.edu"`.  

# Notes
- Script originally by jbabiarz.
- Rewritten by mseng3. See my other projects here: https://github.com/mmseng/code-compendium.
