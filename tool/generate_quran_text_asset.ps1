$ErrorActionPreference = 'Stop'

$outputPath = Join-Path $PSScriptRoot '..\\assets\\quran_pages\\quran_text_by_page.json'
$pages = New-Object System.Collections.Generic.List[object]
$generatedAt = [DateTime]::UtcNow.ToString('o')

for ($page = 1; $page -le 604; $page++) {
  Write-Host "Fetching page $page of 604..."
  $uri = "https://api.quran.com/api/v4/verses/by_page/${page}?words=true&word_fields=text_indopak,line_number,page_number&fields=verse_key&per_page=50"
  $response = Invoke-RestMethod -Uri $uri -Headers @{ Accept = 'application/json' }
  $lineMap = @{}

  foreach ($verse in $response.verses) {
    foreach ($word in $verse.words) {
      if ($word.page_number -ne $page -or [string]::IsNullOrWhiteSpace($word.text_indopak)) {
        continue
      }

      $lineNumber = [int]$word.line_number
      if (-not $lineMap.ContainsKey($lineNumber)) {
        $lineMap[$lineNumber] = New-Object System.Collections.Generic.List[string]
      }

      $lineMap[$lineNumber].Add($word.text_indopak)
    }
  }

  $lines = New-Object System.Collections.Generic.List[object]
  foreach ($entry in $lineMap.GetEnumerator() | Sort-Object Key) {
    $lines.Add([ordered]@{
      lineNumber = [int]$entry.Key
      text = [string]::Join(' ', $entry.Value).Trim()
    })
  }

  $pages.Add([ordered]@{
    pageNumber = $page
    lines = $lines
  })
}

$payload = [ordered]@{
  source = [ordered]@{
    name = 'Quran.com API v4'
    endpoint = 'https://api.quran.com/api/v4/verses/by_page/{page}'
    generatedAt = $generatedAt
    script = 'text_indopak'
    notes = 'Bundled IndoPak 16-line-compatible page text grouped by Mushaf line number for offline app use.'
  }
  pages = $pages
}

$json = $payload | ConvertTo-Json -Depth 8
[System.IO.File]::WriteAllText($outputPath, $json, [System.Text.Encoding]::UTF8)
Write-Host "Saved Quran text asset to $outputPath"
