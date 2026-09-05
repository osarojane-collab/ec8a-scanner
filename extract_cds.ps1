$files = @('ui1','t1','t2','t3','t4','t5','t6','t7','t8','t9','t10','t11','k1state','g1state','g7state','h1export','h2state','h4state')
foreach ($f in $files) {
    $path = "C:\Users\mclde\.cline\data\workspaces\chat\ec8a-scanner\shots\$f.xml"
    if (Test-Path $path) {
        [xml]$x = Get-Content $path -Raw
        $cds = @()
        $stack = @($x.hierarchy)
        while ($stack.Count -gt 0) {
            $n = $stack.Pop()
            $cd = $n.GetAttribute('content-desc')
            if ($cd -and $cd.Length -gt 3) { $cds += $cd }
            foreach ($c in $n.node) { $stack.Push($c) }
        }
        if ($cds) {
            Write-Host ("=== " + $f + " ===")
            $cds | Sort-Object -Unique | ForEach-Object { Write-Host ("  " + $_.Substring(0, [Math]::Min(200, $_.Length)).Replace('&#10;',' | ')) }
        }
    }
}