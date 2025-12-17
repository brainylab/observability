# 📊 Resumo da Configuração SSL Multi-Domínio

## ✅ O que foi configurado

### 🎯 Scripts criados

| Arquivo | Descrição | Uso |
|---------|-----------|-----|
| `setup-ssl.sh` | Configuração inicial SSL para múltiplos domínios | `sudo ./setup-ssl.sh` |
| `renew-ssl-manual.sh` | Renovação manual de certificados | `sudo ./renew-ssl-manual.sh` |
| `renew-ssl-multi.sh` | Renovação automática (criado pelo setup) | Executado via cron |

### 📚 Documentação criada

| Arquivo | Conteúdo |
|---------|----------|
| `README.md` | Documentação completa do projeto |
| `QUICK-START.md` | Guia rápido em 5 passos ⚡ |
| `SSL-SETUP-GUIDE.md` | Guia detalhado de SSL multi-domínio 🔒 |
| `SUMMARY.md` | Este arquivo (resumo visual) |

---

## 🏗️ Arquitetura Multi-Domínio

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet / Cliente                        │
└────────────────┬─────────────────────┬──────────────────────┘
                 │                     │
                 │ HTTPS               │ HTTPS + gRPC
                 ▼                     ▼
    ┌────────────────────┐  ┌─────────────────────┐
    │ uptrace.dominio.com│  │ ingest.dominio.com  │
    │   (UI - Port 443)  │  │ (OTLP - Port 443    │
    │                    │  │        + 4317)      │
    └────────┬───────────┘  └──────────┬──────────┘
             │                         │
             │ SSL Termination (Nginx) │
             │                         │
             └──────────┬──────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  Nginx Container │
              │  - server.crt    │
              │  - ingest.crt    │
              └────────┬─────────┘
                       │ HTTP (interno)
                       ▼
              ┌──────────────────┐
              │ Uptrace Container│
              │   Port 80, 4317  │
              └────────┬─────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ClickHouse     PostgreSQL       Redis
```

---

## 📝 Configuração Necessária

### 1. DNS Records

```
Tipo  | Nome    | Valor           | TTL
------|---------|-----------------|-----
A     | uptrace | IP_DO_SERVIDOR  | 3600
A     | ingest  | IP_DO_SERVIDOR  | 3600
```

### 2. Firewall Rules

```bash
# Portas necessárias
80/tcp   → HTTP (Let's Encrypt validation)
443/tcp  → HTTPS (UI + Ingest HTTP)
4317/tcp → gRPC over TLS (Ingest)
```

### 3. Arquivos para editar

#### 📄 `nginx/nginx.conf`
Substituir em **6 locais**:
```nginx
server_name uptrace.seu-dominio.com;  # 3x (UI)
server_name ingest.seu-dominio.com;   # 3x (Ingest)
```

#### 📄 `uptrace.yml`
```yaml
service:
  secret: <GERAR_RANDOM>  # openssl rand -base64 32

site:
  url: https://uptrace.seu-dominio.com
  ingest_url: https://ingest.seu-dominio.com?grpc=4317
```

---

## 🔐 Certificados SSL Gerados

### Estrutura de arquivos após setup:

```
nginx/ssl/
├── server.crt    # Certificado público da UI
├── server.key    # Chave privada da UI (600)
├── ingest.crt    # Certificado público de Ingestão
└── ingest.key    # Chave privada de Ingestão (600)
```

### Let's Encrypt (origem):

```
/etc/letsencrypt/live/
├── uptrace.seu-dominio.com/
│   ├── fullchain.pem  → copiado para server.crt
│   └── privkey.pem    → copiado para server.key
└── ingest.seu-dominio.com/
    ├── fullchain.pem  → copiado para ingest.crt
    └── privkey.pem    → copiado para ingest.key
```

---

## ⚡ Comandos Rápidos

### Setup Inicial

```bash
# 1. Renomear configuração
mv example-uptrace.yml uptrace.yml

# 2. Editar uptrace.yml
nano uptrace.yml

# 3. Editar nginx.conf
nano nginx/nginx.conf

# 4. Executar SSL setup
chmod +x setup-ssl.sh
sudo ./setup-ssl.sh

# 5. Iniciar serviços
docker-compose up -d
```

### Verificação

```bash
# Testar UI
curl -I https://uptrace.seu-dominio.com

# Testar Ingest
curl -I https://ingest.seu-dominio.com

# Ver logs
docker-compose logs -f nginx uptrace

# Verificar certificados
openssl x509 -in nginx/ssl/server.crt -noout -dates
openssl x509 -in nginx/ssl/ingest.crt -noout -dates
```

### Manutenção

```bash
# Renovar certificados manualmente
sudo ./renew-ssl-manual.sh

# Ver logs de renovação automática
tail -f ssl-renew.log

# Reiniciar serviços
docker-compose restart nginx uptrace

# Backup
tar czf backup-$(date +%Y%m%d).tar.gz uptrace.yml nginx/ docker-compose.yml
```

---

## 🎯 Endpoints Configurados

| Endpoint | URL | Protocolo | Uso |
|----------|-----|-----------|-----|
| **UI Web** | `https://uptrace.seu-dominio.com` | HTTPS | Interface, dashboards |
| **API REST** | `https://uptrace.seu-dominio.com/api/*` | HTTPS | API do Uptrace |
| **OTLP HTTP** | `https://ingest.seu-dominio.com/v1/traces` | HTTPS | Traces HTTP |
| **OTLP HTTP** | `https://ingest.seu-dominio.com/v1/metrics` | HTTPS | Metrics HTTP |
| **OTLP gRPC** | `ingest.seu-dominio.com:4317` | gRPC+TLS | Traces/Metrics gRPC |

---

## 📊 Fluxo de Dados

### Usuário acessando UI:

```
Browser
  → https://uptrace.seu-dominio.com (443)
    → Nginx (SSL termination)
      → Uptrace:80 (HTTP interno)
        → PostgreSQL (metadados)
        → ClickHouse (queries)
```

### Aplicação enviando telemetria (HTTP):

```
App (OpenTelemetry SDK)
  → https://ingest.seu-dominio.com/v1/traces (443)
    → Nginx (SSL termination + rate limit)
      → Uptrace:80/v1/traces (HTTP interno)
        → ClickHouse (armazenamento)
```

### Aplicação enviando telemetria (gRPC):

```
App (OpenTelemetry SDK)
  → ingest.seu-dominio.com:4317 (gRPC+TLS)
    → Nginx (SSL termination + rate limit)
      → Uptrace:4317 (gRPC interno)
        → ClickHouse (armazenamento)
```

---

## 🔄 Renovação Automática

### Cron Job Configurado:

```bash
# Executado diariamente às 3h da manhã
0 3 * * * /caminho/para/renew-ssl-multi.sh >> /caminho/para/ssl-renew.log 2>&1
```

### O que o script faz:

1. ✅ Para o Nginx
2. ✅ Renova certificados com `certbot renew`
3. ✅ Copia novos certificados para `nginx/ssl/`
4. ✅ Reinicia Nginx e Uptrace
5. ✅ Registra em `ssl-renew.log`

### Verificar:

```bash
# Ver cron job
sudo crontab -l | grep renew-ssl

# Ver últimas renovações
tail -20 ssl-renew.log

# Testar renovação (dry-run)
sudo certbot renew --dry-run
```

---

## 🎨 Exemplo de Configuração de App

### Node.js

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'https://ingest.seu-dominio.com:4317',
    headers: {
      'uptrace-dsn': 'https://project_token@ingest.seu-dominio.com?grpc=4317'
    }
  })
});

sdk.start();
```

### Python

```python
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

exporter = OTLPSpanExporter(
    endpoint="https://ingest.seu-dominio.com:4317",
    headers=(("uptrace-dsn", "https://project_token@ingest.seu-dominio.com?grpc=4317"),)
)
```

---

## 📋 Checklist Final

### Antes de ir para produção:

- [ ] DNS configurado e propagado
- [ ] Firewall aberto (portas 80, 443, 4317)
- [ ] `nginx.conf` com domínios corretos
- [ ] `uptrace.yml` com URLs e secret corretos
- [ ] SSL gerado em modo **PRODUÇÃO** (não teste)
- [ ] Teste SSL no [SSL Labs](https://www.ssllabs.com/ssltest/) (A ou A+)
- [ ] UI acessível via HTTPS sem erros
- [ ] Endpoint de ingestão acessível
- [ ] Teste envio de dados de uma app
- [ ] Renovação automática configurada (cron)
- [ ] Backup configurado
- [ ] Senha admin alterada
- [ ] Logs monitorados

---

## 📞 Suporte Rápido

### Erro comum 1: DNS não resolve
```bash
dig +short uptrace.seu-dominio.com  # Deve retornar IP
# Aguarde propagação (5-10 min) ou verifique DNS
```

### Erro comum 2: Certificado inválido
```bash
openssl x509 -in nginx/ssl/server.crt -noout -issuer
# Deve mostrar "Let's Encrypt", não "Fake LE"
# Solução: Re-executar setup-ssl.sh em modo produção
```

### Erro comum 3: CORS error
```bash
# Verifique se URL no uptrace.yml = URL no browser
grep "url:" uptrace.yml
# Reinicie após alterar
docker-compose restart uptrace nginx
```

### Erro comum 4: Porta em uso
```bash
sudo netstat -tlnp | grep :80
sudo systemctl stop apache2  # ou nginx do sistema
```

---

## 🎓 Documentação

| Arquivo | Quando Usar |
|---------|-------------|
| **QUICK-START.md** | Primeira instalação, comandos rápidos |
| **SSL-SETUP-GUIDE.md** | Configurar/troubleshoot SSL, detalhes avançados |
| **README.md** | Documentação completa, referência |
| **SUMMARY.md** | Visão geral rápida, diagramas |

---

## 🚀 Status da Configuração

Após completar todos os passos:

```
✅ Nginx configurado com SSL
✅ Uptrace rodando
✅ ClickHouse armazenando dados
✅ PostgreSQL com metadados
✅ Redis para cache
✅ Certificados SSL válidos
✅ Renovação automática ativa
✅ Domínios separados (UI + Ingest)
✅ Rate limiting configurado
✅ Logs separados
✅ Pronto para produção! 🎉
```

---

**Desenvolvido com ❤️ para BrainyLab**

*Última atualização: Dezembro 2025*