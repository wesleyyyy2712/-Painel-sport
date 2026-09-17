# Compilar a IPA pelo iPhone

O projeto agora inclui o workflow `.github/workflows/build-ipa.yml`. Ele usa um runner macOS hospedado pelo GitHub, portanto você não precisa ter Mac, Xcode ou computador próprio.

## Primeiro uso

1. Crie um repositório no GitHub pelo Safari ou pelo aplicativo do GitHub.
2. Envie todos os arquivos deste projeto para o repositório.
3. Abra a aba **Actions** do repositório.
4. Selecione **Build 3105 IPA**.
5. Toque em **Run workflow**.
6. Quando terminar, abra a execução concluída e baixe o artefato **3105-unsigned-ipa**.

O arquivo gerado é uma IPA sem assinatura. Para instalar no iPhone, ela ainda precisa ser assinada com um certificado e perfil de provisionamento compatíveis. O workflow atual não contém certificados nem tenta burlar a assinatura da Apple.

## Instalação assinada

Para gerar uma IPA instalável diretamente, será necessário configurar no GitHub Secrets um certificado de distribuição em formato `.p12`, a senha do certificado, um perfil `.mobileprovision` e os identificadores correspondentes. O Bundle ID atual do projeto é `com.apple.mobile.MobileHouseArrest`; ele só pode ser usado se você tiver autorização e provisionamento compatível para esse identificador.

Nunca coloque certificados, senhas ou perfis de provisionamento dentro do repositório. Use somente **Settings → Secrets and variables → Actions**.

## Comportamento dos patches

Ao importar um pacote `.3105`, ele aparece em **Installed** com um switch lateral:

- **Ligado:** aplica o patch e cria o backup dos arquivos originais.
- **Desligado:** restaura os arquivos originais e remove as alterações aplicadas.
- **Excluir:** remove o pacote importado apenas quando não há patch ativo.

A aplicação continua exigindo que os aplicativos-alvo estejam fechados e que o usuário confirme a operação quando ela é feita pela tela de detalhes.
