# SonarQube - Automação para Alterar Visibilidade de Projetos

Este repositório contém um script PowerShell para alterar em massa a visibilidade de projetos no SonarQube de `public` para `private`.

## Sobre o Script

O script `update_sonarqube_visibility.ps1` conecta-se à API do SonarQube, percorre todos os projetos existentes usando paginação e atualiza a visibilidade de qualquer projeto público para privado. É uma ferramenta útil para reforçar políticas de segurança e governança de código.

## Como Executar

1.  **Abra o PowerShell.**
2.  **Clone o repositório** ou baixe o script para sua máquina local.
3.  **Edite o script** `update_sonarqube_visibility.ps1` e atualize as seguintes variáveis no bloco de parâmetros com os dados da sua instância:
    * `$sonarUrl`: A URL do seu SonarQube (ex: `"http://localhost:9000"`).
    * `$adminToken`: Seu token de acesso de administrador.
4.  **Navegue até o diretório** onde o script está localizado:
    ```powershell
    cd caminho\para\o\script
    ```
5.  **Execute o script:**
    ```powershell
    .\update_sonarqube_visibility.ps1
    ```

O script exibirá o progresso no console, informando quais projetos foram alterados e quais já estavam com a visibilidade correta.

---

*Nota: Os comentários detalhados no código-fonte e este arquivo README foram gerados com o auxílio da I.A. Gemini do Google.*
