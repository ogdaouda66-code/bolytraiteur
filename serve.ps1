param(
    [int]$Port = 8000,
    [string]$Root = (Get-Location).Path
)

$listener = [System.Net.HttpListener]::new()
$prefix = "http://127.0.0.1:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serveur actif sur $prefix"

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $requestedPath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath)
        if ($requestedPath -eq "/") {
            $requestedPath = "/index.html"
        }

        $relativePath = $requestedPath.TrimStart('/')
        $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $relativePath))
        $rootFullPath = [System.IO.Path]::GetFullPath($Root)

        if (-not $fullPath.StartsWith($rootFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $context.Response.StatusCode = 403
            $body = [System.Text.Encoding]::UTF8.GetBytes("Accès refusé")
            $context.Response.ContentType = "text/plain; charset=utf-8"
            $context.Response.ContentLength64 = $body.Length
            $context.Response.OutputStream.Write($body, 0, $body.Length)
            $context.Response.OutputStream.Close()
            continue
        }

        if (Test-Path $fullPath -PathType Leaf) {
            $bytes = [System.IO.File]::ReadAllBytes($fullPath)
            $extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
            $mimeType = switch ($extension) {
                ".html" { "text/html; charset=utf-8" }
                ".css" { "text/css; charset=utf-8" }
                ".js" { "application/javascript; charset=utf-8" }
                ".json" { "application/json; charset=utf-8" }
                ".png" { "image/png" }
                ".jpg" { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".svg" { "image/svg+xml" }
                default { "application/octet-stream" }
            }

            $response = $context.Response
            $response.ContentType = $mimeType
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
        }
        else {
            $response = $context.Response
            $response.StatusCode = 404
            $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.ContentType = "text/plain; charset=utf-8"
            $response.ContentLength64 = $body.Length
            $response.OutputStream.Write($body, 0, $body.Length)
            $response.OutputStream.Close()
        }
    }
    catch {
        if ($listener.IsListening) {
            continue
        }
    }
}

$listener.Stop()
$listener.Close()
