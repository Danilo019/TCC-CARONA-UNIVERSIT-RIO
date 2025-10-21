# Script para converter SHA-1 para Signature Hash (Base64)
# Autor: Assistente IA
# Uso: .\converter_sha1_para_base64.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Conversor SHA-1 para Signature Hash" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Solicita o SHA-1
Write-Host "Cole o SHA-1 do seu keystore (exemplo: A1:B2:C3:D4:E5:F6...)" -ForegroundColor Yellow
Write-Host "SHA-1: " -NoNewline -ForegroundColor Green
$sha1 = Read-Host

# Remove espaços e dois-pontos
$sha1Clean = $sha1 -replace '[:\s]', ''

Write-Host ""
Write-Host "SHA-1 limpo: $sha1Clean" -ForegroundColor White

try {
    # Converte HEX para bytes
    $bytes = [byte[]]::new($sha1Clean.Length / 2)
    For($i=0; $i -lt $sha1Clean.Length; $i+=2) {
        $bytes[$i/2] = [Convert]::ToByte($sha1Clean.Substring($i, 2), 16)
    }
    
    # Converte bytes para Base64
    $base64 = [Convert]::ToBase64String($bytes)
    
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Green
    Write-Host "SIGNATURE HASH (Base64):" -ForegroundColor Green
    Write-Host $base64 -ForegroundColor Yellow
    Write-Host "==================================" -ForegroundColor Green
    Write-Host ""
    
    # Mostra o redirect URI completo
    $redirectUri = "msauth://com.carona.universitaria/$base64"
    Write-Host "Redirect URI completo:" -ForegroundColor Cyan
    Write-Host $redirectUri -ForegroundColor White
    Write-Host ""
    
    # Copia para clipboard
    try {
        Set-Clipboard -Value $base64
        Write-Host "✓ Signature hash copiado para a área de transferência!" -ForegroundColor Green
    } catch {
        Write-Host "⚠ Não foi possível copiar automaticamente. Copie manualmente acima." -ForegroundColor Yellow
    }
    
} catch {
    Write-Host ""
    Write-Host "ERRO: SHA-1 inválido. Certifique-se de colar o formato correto." -ForegroundColor Red
    Write-Host "Exemplo: A1:B2:C3:D4:E5:F6:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

