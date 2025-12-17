# 🔒 Guia de Configuração SSL Multi-Domínio

Este guia explica como configurar certificados SSL/TLS válidos do Let's Encrypt para **dois domínios separados**: um para a interface web (UI) e outro para ingestão de dados (OTLP).

---

## 📋 Por que usar domínios separados?

### Vantagens:

✅ **Isolamento de tráfego** - Tráfego de usuários separado de telemetria  
✅ **Segurança** - Políticas diferentes para UI e API de ingestão  
✅ **Performance** - Rate limiting e cache específicos  
✅ **Escalabilidade** - Pode escalar cada componente independentemente  
✅ **Monitoramento** - Logs e métricas separados  
✅ **CDN** - Pode usar CDN apenas para UI  

### Exemplo de configuração:

| Componente | Domínio | Porta | Uso |
|------------|---------|-------|-----|
| **UI** | `uptrace.exemplo.com` | 443 (HTTPS) | Interface web, dashboards |
| **Ingestão HTTP** | `ingest.exemplo.com` | 443 (HTTPS) | OTLP/HTTP endpoint |
| **Ingestão gRPC** | `ingest.exemplo.com` | 4317 (SSL) | OTLP/gRPC endpoint |

---

## 🚀 Configuração Rápida

### Pré-requisitos

1. **Dois domínios/subdomínios** configurados no DNS apontando para o servidor:
   ```
   uptrace.exemplo.com  →  123.45.67.89
   ingest.exemplo.com   →  123.45.67.89
   ```

2. **Portas abertas** no firewall:
   ```bash
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw allow 4317/tcp
   ```

3. **DNS propagado** (verifique):
   ```bash
   dig +short uptrace.exemplo.com
   dig +short ingest.exemplo.com
   ```

---

## 📝 Passo a Passo

### 1. Configurar DNS

Antes de tudo, configure seus registros DNS:

```
Tipo: A
Nome: uptrace
Valor: SEU-IP-SERVIDOR
TTL: 3600

Tipo: A
Nome: ingest
Valor: SEU-IP-SERVIDOR
TTL: 3600
```

**Aguarde** 5-10 minutos para propagação do DNS.

### 2. Atualizar nginx.conf

Edite o arquivo `nginx/nginx.conf` e substitua os domínios:

```bash
nano nginx/nginx.conf
```

Procure e **substitua** estas linhas:

```nginx
# ANTES:
server_name seu-dominio.com;

# DEPOIS:
server_name uptrace.exemplo.com;  # Para o bloco da UI
server_name ingest.exemplo.com;   # Para o bloco de ingestão
```

**Locais para alterar:**
- Linha ~30: `server_name uptrace.seu-dominio.com;`
- Linha ~40: `server_name uptrace.seu-dominio.com;`
- Linha ~115: `server_name ingest.seu-dominio.com;`
- Linha ~125: `server_name ingest.seu-dominio.com;`
- Linha ~170: `server_name ingest.seu-dominio.com;`

### 3. Executar script de configuração SSL

```bash
# Tornar executável
chmod +x setup-ssl.sh

# Executar como root
sudo ./setup-ssl.sh
```

**O script irá perguntar:**

```
Digite o domínio da UI (ex: uptrace.exemplo.com): uptrace.exemplo.com
Digite o domínio de ingestão (ex: ingest.exemplo.com): ingest.exemplo.com
Digite seu email: seu-email@exemplo.com
Usar certificado de TESTE? (recomendado na primeira vez) [s/N]: s
```

**Primeira execução (TESTE):**
- Digite `s` para modo teste
- Verifica se tudo está configurado corretamente
- Gera certificados de teste (não válidos)

**Segunda execução (PRODUÇÃO):**
```bash
sudo ./setup-ssl.sh
# ... (mesmas perguntas)
# Usar certificado de TESTE? [s/N]: n  ← Digite 'n'
```

### 4. Atualizar uptrace.yml

Edite o arquivo `uptrace.yml`:

```bash
nano uptrace.yml
```

Atualize a seção `site`:

```yaml
site:
  # URL da interface web
  url: https://uptrace.exemplo.com

  # URL de ingestão (domínio separado)
  ingest_url: https://ingest.exemplo.com?grpc=4317
```

### 5. Reiniciar serviços

```bash
docker-compose restart nginx uptrace
```

### 6. Verificar funcionamento

```bash
# Testar UI
curl -I https://uptrace.exemplo.com

# Testar Ingest HTTP
curl -I https://ingest.exemplo.com

# Ver logs
docker-compose logs -f nginx uptrace
```

---

## 📂 Estrutura de Certificados

Após a configuração, você terá:

```
nginx/ssl/
├── server.crt      # Certificado da UI (uptrace.exemplo.com)
├── server.key      # Chave privada da UI
├── ingest.crt      # Certificado de ingestão (ingest.exemplo.com)
└── ingest.key      # Chave privada de ingestão
```

---

## 🔄 Renovação de Certificados

### Renovação Automática

O script já configurou renovação automática via **cron**:

```bash
# Verificar cron job
sudo crontab -l | grep renew-ssl

# Saída esperada:
0 3 * * * /caminho/para/renew-ssl-multi.sh >> /caminho/para/ssl-renew.log 2>&1
```

Os certificados serão renovados **automaticamente** todos os dias às 3h da manhã.

### Renovação Manual

Se necessário, renove manualmente:

```bash
# Usar o script automático
chmod +x renew-ssl-manual.sh
sudo ./renew-ssl-manual.sh

# Ou manualmente com certbot
sudo docker-compose stop nginx
sudo certbot renew
sudo ./setup-ssl.sh  # Re-executar para copiar certificados
```

### Testar Renovação (Dry Run)

```bash
sudo certbot renew --dry-run
```

---

## 🔍 Verificação de Certificados

### Verificar validade

```bash
# Certificado da UI
openssl x509 -in nginx/ssl/server.crt -noout -dates

# Certificado de Ingestão
openssl x509 -in nginx/ssl/ingest.crt -noout -dates

# Verificar domínios
openssl x509 -in nginx/ssl/server.crt -noout -subject
openssl x509 -in nginx/ssl/ingest.crt -noout -subject
```

### Testar SSL online

Acesse e teste a qualidade do SSL:
- **SSL Labs**: https://www.ssllabs.com/ssltest/
- Digite: `uptrace.exemplo.com`
- Digite: `ingest.exemplo.com`

### Testar com curl

```bash
# UI
curl -vI https://uptrace.exemplo.com 2>&1 | grep -E "subject|expire|CN"

# Ingest
curl -vI https://ingest.exemplo.com 2>&1 | grep -E "subject|expire|CN"

# gRPC (se tiver grpcurl instalado)
grpcurl ingest.exemplo.com:4317 list
```

---

## 🔧 Configuração de Aplicações

### Enviar dados via OTLP HTTP

```javascript
// Node.js
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const exporter = new OTLPTraceExporter({
  url: 'https://ingest.exemplo.com/v1/traces',
  headers: {
    'uptrace-dsn': 'https://project_token@ingest.exemplo.com?grpc=4317'
  }
});
```

### Enviar dados via OTLP gRPC

```javascript
// Node.js
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const exporter = new OTLPTraceExporter({
  url: 'https://ingest.exemplo.com:4317',
  headers: {
    'uptrace-dsn': 'https://project_token@ingest.exemplo.com?grpc=4317'
  }
});
```

```python
# Python
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

exporter = OTLPSpanExporter(
    endpoint="https://ingest.exemplo.com:4317",
    headers=(("uptrace-dsn", "https://project_token@ingest.exemplo.com?grpc=4317"),)
)
```

```go
// Go
import "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"

exporter, _ := otlptracegrpc.New(
    context.Background(),
    otlptracegrpc.WithEndpoint("ingest.exemplo.com:4317"),
    otlptracegrpc.WithHeaders(map[string]string{
        "uptrace-dsn": "https://project_token@ingest.exemplo.com?grpc=4317",
    }),
)
```

---

## 🐛 Troubleshooting

### Problema: DNS não resolve

```bash
# Verificar DNS
dig +short uptrace.exemplo.com
dig +short ingest.exemplo.com

# Deve retornar o IP do servidor
# Se não retornar, aguarde propagação ou verifique configuração DNS
```

### Problema: Certificado não é válido

**Sintoma:** Navegador mostra certificado inválido

**Solução:**
1. Verifique se executou em modo PRODUÇÃO (não teste):
   ```bash
   sudo ./setup-ssl.sh
   # Usar certificado de TESTE? [s/N]: n  ← Deve ser 'n'
   ```

2. Verifique se o domínio está correto:
   ```bash
   openssl x509 -in nginx/ssl/server.crt -noout -text | grep DNS
   ```

### Problema: Porta 80 ou 443 em uso

```bash
# Identificar processo
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Parar serviço conflitante
sudo systemctl stop apache2  # ou nginx
```

### Problema: Let's Encrypt rate limit

**Erro:** `too many certificates already issued`

**Solução:**
- Use modo TESTE primeiro: `./setup-ssl.sh` → `s` (teste)
- Aguarde 1 semana para o limite resetar
- Ou use domínios diferentes

### Problema: Certificados não renovam automaticamente

```bash
# Verificar cron
sudo crontab -l | grep renew

# Verificar logs
cat ssl-renew.log

# Testar renovação manual
sudo certbot renew --dry-run

# Re-adicionar cron se necessário
(sudo crontab -l 2>/dev/null; echo "0 3 * * * $(pwd)/renew-ssl-multi.sh >> $(pwd)/ssl-renew.log 2>&1") | sudo crontab -
```

### Problema: Nginx não inicia após SSL

```bash
# Testar configuração
docker-compose exec nginx nginx -t

# Ver logs
docker-compose logs nginx

# Verificar permissões dos certificados
ls -la nginx/ssl/

# Reiniciar
docker-compose restart nginx
```

---

## 📊 Monitoramento

### Verificar uso de certificados

```bash
# Criar script de monitoramento
cat > check-ssl-expiry.sh << 'EOF'
#!/bin/bash
echo "Verificando validade dos certificados..."
echo ""
echo "UI Certificate:"
openssl x509 -in nginx/ssl/server.crt -noout -dates
echo ""
echo "Ingest Certificate:"
openssl x509 -in nginx/ssl/ingest.crt -noout -dates
echo ""

# Calcular dias restantes
UI_EXPIRY=$(openssl x509 -in nginx/ssl/server.crt -noout -enddate | cut -d= -f2)
INGEST_EXPIRY=$(openssl x509 -in nginx/ssl/ingest.crt -noout -enddate | cut -d= -f2)

echo "Certificados expiram em:"
echo "UI: $UI_EXPIRY"
echo "Ingest: $INGEST_EXPIRY"
EOF

chmod +x check-ssl-expiry.sh
./check-ssl-expiry.sh
```

### Alertas de expiração

```bash
# Adicionar ao cron para verificar diariamente
(crontab -l 2>/dev/null; echo "0 9 * * * $(pwd)/check-ssl-expiry.sh | mail -s 'SSL Status' seu@email.com") | crontab -
```

---

## 🔐 Segurança Adicional

### HSTS (HTTP Strict Transport Security)

Já configurado no `nginx.conf`:
```nginx
add_header Strict-Transport-Security "max-age=63072000" always;
```

### Rate Limiting

Configurado para ingestão:
```nginx
limit_req_zone $binary_remote_addr zone=ingest_limit:10m rate=100r/s;
limit_req zone=ingest_limit burst=200 nodelay;
```

### Logs separados

```bash
# Ver logs da UI
docker-compose exec nginx tail -f /var/log/nginx/access.log

# Ver logs de ingestão
docker-compose exec nginx tail -f /var/log/nginx/ingest-access.log

# Ver logs gRPC
docker-compose exec nginx tail -f /var/log/nginx/grpc-access.log
```

---

## 📚 Referências

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot User Guide](https://certbot.eff.org/docs/using.html)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Uptrace Documentation](https://uptrace.dev/get/get-started.html)
- [OpenTelemetry Protocol (OTLP)](https://opentelemetry.io/docs/specs/otlp/)

---

## ✅ Checklist de Configuração

Antes de ir para produção, verifique:

- [ ] DNS configurado e propagado para ambos os domínios
- [ ] Portas 80, 443 e 4317 abertas no firewall
- [ ] `nginx.conf` atualizado com domínios corretos
- [ ] `uptrace.yml` atualizado com URLs corretas
- [ ] Certificados gerados em modo PRODUÇÃO (não teste)
- [ ] Nginx iniciado sem erros
- [ ] UI acessível via HTTPS
- [ ] Endpoint de ingestão acessível
- [ ] Renovação automática configurada (cron)
- [ ] SSL testado no SSL Labs (nota A ou A+)
- [ ] Aplicações enviando dados com sucesso
- [ ] Logs sendo gerados corretamente
- [ ] Backup dos certificados configurado

---

**Desenvolvido com ❤️ para BrainyLab**

*Última atualização: Dezembro 2025*