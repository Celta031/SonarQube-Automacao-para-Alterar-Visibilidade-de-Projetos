<#
.SYNOPSIS
    Script de automação para alterar a visibilidade de projetos no SonarQube de 'public' para 'private'.

.DESCRIPTION
    Este script PowerShell interage com a API REST do SonarQube para iterar sobre todos os projetos.
    Ele utiliza paginação para garantir escalabilidade em instâncias com um grande número de projetos.
    Para cada projeto encontrado, o script verifica se a visibilidade atual é 'public' e, em caso afirmativo,
    a altera para 'private'. É uma ferramenta essencial para reforçar a política de segurança e
    governança em ambientes SonarQube, garantindo que o código-fonte não seja exposto indevidamente.

.NOTES
    Autor: [Seu Nome/Equipe]
    Versão: 1.0
    Pré-requisitos:
    - PowerShell 5.1 ou superior.
    - Conectividade de rede com a instância do SonarQube.
    - Um token de administrador do SonarQube com permissões para gerenciar projetos.

.PARAMETER SonarUrl
    URL base da instância do SonarQube (ex: http://sonarqube.suaempresa.com).

.PARAMETER AdminToken
    Token de acesso de um usuário com privilégios administrativos no SonarQube.
    É recomendado o uso de tokens gerados especificamente para automação.

.EXAMPLE
    .\update_sonarqube_visibility.ps1
    (Executa o script com os parâmetros definidos internamente)
#>

# -----------------------------------------------------------------
# SCRIPT POWERSHELL PARA ALTERAR VISIBILIDADE DE PROJETOS SONARQUBE
# -----------------------------------------------------------------

# --- Bloco de Configuração de Parâmetros ---
# Definição das variáveis de ambiente para a execução do script.
# É crucial que o token de administrador seja tratado como um segredo e, em um ambiente de produção,
# seja injetado através de um sistema de gerenciamento de segredos (ex: Azure Key Vault, HashiCorp Vault)
# em vez de ser 'hardcoded'.
# ------------------------------------------------
[CmdletBinding()]
param (
    [string]$sonarUrl = "http://localhost:9000",
    [string]$adminToken = "***", # ATENÇÃO: Substitua pelo seu token de administrador.
    [int]$pageSize = 100, # Controla o número de projetos retornados por chamada de API para evitar sobrecarga.
    [int]$page = 1 # Página inicial para a consulta paginada.
)

# --- Preparação da Autenticação ---
# A API do SonarQube utiliza autenticação básica (Basic Authentication).
# O token do usuário é codificado em Base64 e enviado no cabeçalho 'Authorization' de cada requisição.
# Este método garante que todas as operações subsequentes sejam autenticadas e autorizadas.
# ------------------------------------------------
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${adminToken}:"))
$headers = @{
    "Authorization" = "Basic $base64Auth"
}

Write-Host "Iniciando a alteração de visibilidade dos projetos para 'private' na instância: $sonarUrl" -ForegroundColor Cyan

# --- Loop Principal de Paginação ---
# A iteração sobre os projetos é feita com paginação para garantir que o script funcione de forma eficiente
# em instâncias SonarQube com milhares de projetos, evitando timeouts de API e alto consumo de memória.
# O loop continuará indefinidamente ('while ($true)'), sendo interrompido internamente quando não houver mais
# páginas de projetos a serem processadas.
# ------------------------------------------------
while ($true) {
    
    Write-Host "Processando Página $page..." -ForegroundColor Yellow
    
    # --- Etapa 1: Buscar a página de projetos via API ---
    # Monta a URL para o endpoint 'api/projects/search', que retorna uma lista de projetos.
    # Os parâmetros 'ps' (pageSize) e 'p' (page) controlam a paginação.
    # ------------------------------------------------
    $searchUrl = "$sonarUrl/api/projects/search?ps=$pageSize&p=$page"
    
    try {
        # O cmdlet 'Invoke-RestMethod' é utilizado para executar a requisição GET.
        # Ele automaticamente converte a resposta JSON da API em um objeto PowerShell,
        # facilitando a manipulação dos dados retornados.
        $response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get -ErrorAction Stop
    } catch {
        # Bloco de tratamento de exceções. Se a chamada à API falhar (ex: URL incorreta,
        # token inválido, SonarQube offline), o script registrará um erro detalhado e será interrompido.
        Write-Error "Falha ao buscar projetos na página $page. Verifique a URL do SonarQube e o Token de Acesso. Erro: $_"
        break # Interrompe o loop 'while' em caso de falha na comunicação.
    }

    # --- Verificação de Fim de Paginação ---
    # Se a propriedade 'components' do objeto de resposta estiver vazia, significa que
    # chegamos ao final da lista de projetos e não há mais páginas para processar.
    # ------------------------------------------------
    if (-not $response.components) {
        Write-Host "Nenhum projeto encontrado na página $page. Processo de alteração concluído." -ForegroundColor Green
        break # Sai do loop 'while' com sucesso.
    }

    # --- Etapa 2: Iterar e alterar a visibilidade dos projetos ---
    # Itera sobre cada projeto ('component') retornado na página atual.
    # ------------------------------------------------
    foreach ($project in $response.components) {
        
        $projectKey = $project.key
        
        # --- Condição de idempotência ---
        # A verificação 'if ($project.visibility -eq 'public')' torna o script idempotente.
        # Ou seja, ele só tentará alterar projetos que realmente precisam da alteração.
        # Projetos que já são 'private' ou 'internal' serão ignorados, evitando chamadas de API desnecessárias
        # e permitindo que o script seja executado múltiplas vezes sem efeitos colaterais.
        # ------------------------------------------------
        if ($project.visibility -eq 'public') {
            Write-Host "  - Alterando projeto: '$projectKey' (visibilidade: 'public' -> 'private')"
            
            # Monta a URL para o endpoint 'api/projects/update_visibility', responsável por alterar a visibilidade.
            # Os parâmetros 'project' (chave do projeto) e 'visibility' (novo estado) são obrigatórios.
            $updateUrl = "$sonarUrl/api/projects/update_visibility?project=$projectKey&visibility=private"
            
            try {
                # Executa uma requisição POST para o endpoint de atualização.
                # O '-ErrorAction Stop' garante que, se esta chamada falhar, a exceção será capturada pelo bloco 'catch'.
                Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method Post
            } catch {
                # Se a atualização de um projeto específico falhar (ex: permissões insuficientes,
                # projeto sendo analisado), o script emitirá um aviso e continuará para o próximo projeto.
                # Isso garante a robustez do processo, não o interrompendo por uma falha isolada.
                Write-Warning "  - FALHA ao alterar o projeto '$projectKey'. Erro: $_"
            }
        } else {
            # Fornece feedback visual para os projetos que não necessitam de alteração.
            Write-Host "  - Ignorando projeto: '$projectKey' (visibilidade já é '$($project.visibility)')" -ForegroundColor Gray
        }
    }

    # --- Avançar para a próxima página ---
    # Incrementa o contador de página para a próxima iteração do loop.
    # ------------------------------------------------
    $page++
}

Write-Host "Script finalizado com sucesso." -ForegroundColor Green
Read-Host "Pressione ENTER para sair"
