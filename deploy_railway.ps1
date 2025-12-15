# Script para facilitar deploy do backend Railway
# Execute com: .\deploy_railway.ps1

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Deploy Backend Railway - Sistema de Tokens E-mail      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar se está na pasta correta
if (-Not (Test-Path "backend/server.js")) {
    Write-Host "❌ Erro: Execute este script na raiz do projeto!" -ForegroundColor Red
    Write-Host "   Navegue para a pasta TCC-CARONA-UNIVERSITARIO" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Pasta correta detectada" -ForegroundColor Green
Write-Host ""

# 2. Verificar dependências do backend
Write-Host "📦 Verificando dependências do backend..." -ForegroundColor Cyan
Set-Location backend

if (-Not (Test-Path "node_modules")) {
    Write-Host "   Instalando dependências..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro ao instalar dependências" -ForegroundColor Red
        Set-Location ..
        exit 1
    }
}

Write-Host "✓ Dependências verificadas" -ForegroundColor Green
Write-Host ""

# 3. Testar servidor localmente (opcional)
Write-Host "🧪 Deseja testar o servidor localmente primeiro? (s/n)" -ForegroundColor Cyan
$testar = Read-Host

if ($testar -eq "s" -or $testar -eq "S") {
    Write-Host "   Iniciando servidor local..." -ForegroundColor Yellow
    Write-Host "   Pressione Ctrl+C para parar" -ForegroundColor Gray
    Write-Host ""
    
    $env:NODE_ENV = "development"
    node server.js
}

# 4. Voltar para raiz
Set-Location ..

# 5. Verificar se Railway CLI está instalado
Write-Host "🚂 Verificando Railway CLI..." -ForegroundColor Cyan
$railwayCli = Get-Command railway -ErrorAction SilentlyContinue

if (-Not $railwayCli) {
    Write-Host "❌ Railway CLI não encontrado!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Para instalar Railway CLI:" -ForegroundColor Yellow
    Write-Host "1. Via npm: npm install -g @railway/cli" -ForegroundColor White
    Write-Host "2. Via scoop: scoop install railway" -ForegroundColor White
    Write-Host ""
    Write-Host "Ou faça deploy manual via:" -ForegroundColor Yellow
    Write-Host "1. Acesse https://railway.app" -ForegroundColor White
    Write-Host "2. Conecte seu repositório GitHub" -ForegroundColor White
    Write-Host "3. Configure as variáveis de ambiente" -ForegroundColor White
    exit 1
}

Write-Host "✓ Railway CLI encontrado" -ForegroundColor Green
Write-Host ""

# 6. Fazer login no Railway
Write-Host "🔐 Fazendo login no Railway..." -ForegroundColor Cyan
railway login

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erro ao fazer login" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Login realizado" -ForegroundColor Green
Write-Host ""

# 7. Listar projetos
Write-Host "📋 Seus projetos Railway:" -ForegroundColor Cyan
railway list

Write-Host ""
Write-Host "Digite o ID ou nome do projeto (ou Enter para criar novo):" -ForegroundColor Cyan
$projeto = Read-Host

if ($projeto) {
    # Link com projeto existente
    railway link $projeto
} else {
    # Criar novo projeto
    Write-Host "Digite o nome do novo projeto:" -ForegroundColor Cyan
    $nomeProjeto = Read-Host
    railway init -n $nomeProjeto
}

Write-Host ""

# 8. Configurar variáveis de ambiente
Write-Host "⚙️  Configurando variáveis de ambiente..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Você tem o arquivo JSON do Firebase Service Account? (s/n)" -ForegroundColor Yellow
$temJson = Read-Host

if ($temJson -eq "s" -or $temJson -eq "S") {
    Write-Host "Digite o caminho completo do arquivo JSON:" -ForegroundColor Cyan
    $caminhoJson = Read-Host
    
    if (Test-Path $caminhoJson) {
        # Ler e minificar JSON
        $json = (Get-Content $caminhoJson -Raw) -replace '\s+', ' '
        
        # Configurar variável no Railway
        Write-Host "   Configurando FIREBASE_SERVICE_ACCOUNT..." -ForegroundColor Yellow
        railway variables set FIREBASE_SERVICE_ACCOUNT="$json"
        
        Write-Host "✓ Variável configurada" -ForegroundColor Green
    } else {
        Write-Host "❌ Arquivo não encontrado!" -ForegroundColor Red
        Write-Host "   Configure manualmente no Railway Dashboard" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Configure manualmente no Railway Dashboard:" -ForegroundColor Yellow
    Write-Host "   https://railway.app → seu projeto → Variables" -ForegroundColor White
}

Write-Host ""

# 9. Deploy
Write-Host "🚀 Fazendo deploy..." -ForegroundColor Cyan
Write-Host "   Isso pode levar alguns minutos..." -ForegroundColor Gray
Write-Host ""

railway up

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              ✓ Deploy realizado com sucesso!             ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    # Obter URL
    Write-Host "📡 Obtendo URL do projeto..." -ForegroundColor Cyan
    $url = railway status
    Write-Host ""
    Write-Host "Sua aplicação está rodando!" -ForegroundColor Green
    Write-Host "Acesse o Railway Dashboard para ver a URL pública" -ForegroundColor White
    Write-Host ""
    Write-Host "Próximos passos:" -ForegroundColor Cyan
    Write-Host "1. Copie a URL pública do Railway Dashboard" -ForegroundColor White
    Write-Host "2. Atualize lib/services/email_token_service.dart" -ForegroundColor White
    Write-Host "3. Execute: flutter pub get" -ForegroundColor White
    Write-Host "4. Teste o sistema!" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                  ❌ Erro no deploy                        ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifique os logs acima para mais detalhes" -ForegroundColor Yellow
    Write-Host "Ou acesse: railway logs" -ForegroundColor White
}

Write-Host ""
Write-Host "Pressione qualquer tecla para sair..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
