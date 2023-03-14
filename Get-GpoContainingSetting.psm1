# Originally by James Babiarz
# Re-written by Matt Seng

function Get-GpoContainingSetting {
	param(
		[string]$SettingQuery,
		[string]$GpoNameQuery = "*",
		[string]$Domain = "ad.uillinois.edu"
	)
	
	function log($msg) {
		param(
			[string]$Msg,
			[int]$L = 0
		)
		$indent = ""
		for($i = 0; $i -lt $L; $i += 1) {
			$indent = "    $indent"
		}
		$ts = Get-Date -Format "FileDateTime"
		Write-Host "[$ts]$($indent) $msg"
	}
	
	log "Importing Group Policy Management module..."
	Import-Module grouppolicy 
	
	log "Getting all the GPOs in domain: `"$Domain`" ..."
	$allGpos = Get-GPO -All -Domain $Domain
	
	log "Filtering GPOs by given value of -GpoNameQuery: `"$GpoNameQuery`"..."
	$filteredGpos = $allGpos | Where { $_.DisplayName -like $GpoNameQuery }
	
	log "Searching XML in filtered GPOs..."
	
	[string[]] $MatchedGPOList = @()
	
	$matchedGpos = $filteredGpos | ForEach-Object {
		$gpo = $_
		$report = Get-GPOReport -Guid $gpo.Id -ReportType "Xml"
		if($report -match $SettingQuery) { 
			log "Found match: `"$($gpo.DisplayName)" -L 1
			$($gpo.DisplayName
		}
	}
}