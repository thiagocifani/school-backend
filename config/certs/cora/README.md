# Certificados Cora

Para integração com a API do Cora, coloque os seguintes arquivos neste diretório:

- `certificate.crt` - Certificado do cliente
- `private-key.key` - Chave privada do cliente

## Como usar:

1. Obtenha os certificados do portal do Cora
2. Salve como `certificate.crt` e `private-key.key` neste diretório
3. Configure as variáveis no arquivo `.env`:
   - `CORA_BASE_URL=https://matls-clients.api.stage.cora.com.br`
   - `CORA_CLIENT_ID=seu-client-id`
   - `CORA_CERTIFICATE_PATH=config/certs/cora/certificate.crt`
   - `CORA_PRIVATE_KEY_PATH=config/certs/cora/private-key.key`

## Segurança:
- ⚠️ **NUNCA** commite os arquivos de certificado no git
- Use apenas em ambiente de desenvolvimento/staging
- Para produção, configure secrets seguros