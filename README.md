# 🔭 Observability Stack - Uptrace

Stack completa de observabilidade com **Uptrace**, **ClickHouse**, **PostgreSQL** e **Redis** usando Docker Compose com proxy reverso Nginx e SSL/TLS.

## 📋 Índice

- [Pré-requisitos](#pré-requisitos)
- [Arquitetura](#arquitetura)
- [Instalação](#instalação)
- [Configuração SSL/TLS](#configuração-ssltls)
- [Uso](#uso)
- [Manutenção](#manutenção)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Pré-requisitos

Antes de começar, certifique-se de ter instalado:

- **Docker** (versão 20.10+)
- **Docker Compose** (versão 2.0+)
- **Domínio** apontando para o servidor (para SSL válido)
- **Portas abertas**: 80, 443, 4317

```bash
# Verificar instalação
docker --version
docker compose --version
```

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                     Cliente (Browser)                    │
└────────────────────────┬────────────────────────────────┘
                         │ HTTPS (443) / gRPC (4317)
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Nginx (Proxy Reverso)                  │
│              - Terminação SSL/TLS                        │
│              - Load Balancing                            │
│              - CORS Headers                              │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP (interno)
                         ▼
┌─────────────────────────────────────────────────────────┐
│                        Uptrace                           │
│              - UI Web                                    │
│              - API REST                                  │
│              - OTLP Collector (integrado)                │
└──────┬──────────────┬──────────────┬────────────────────┘
       │              │              │
       ▼              ▼              ▼
  ClickHouse    PostgreSQL        Redis
  (Métricas)    (Metadados)      (Cache)
```

---

## 📦 Instalação

### Passo 1: Clonar/Baixar o projeto

```bash
git clone git@github.com:brainylab/observability.git
cd observability
```

### Passo 2: Configurar o Uptrace

#### 2.1 Renomear arquivo de exemplo

```bash
# Renomear o arquivo de configuração de exemplo
mv example-uptrace.yml uptrace.yml
```

#### 2.2 Editar configurações do Uptrace

Abra o arquivo `uptrace.yml` e atualize as seguintes seções:

```bash
nano uptrace.yml
```

**Configurações importantes:**

```yaml
service:
  env: production  # ou: hosted, development
  secret: ALTERE-ESTE-SECRET-AQUI  # Use uma string aleatória segura

site:
  # URL onde o Uptrace será acessado
  url: https://seu-dominio.com  # ou http://seu-ip (sem SSL)
  
  # URL para ingestão de dados OTLP
  ingest_url: https://seu-dominio.com?grpc=4317
```

**Dica de segurança:** Gere um secret aleatório:
```bash
openssl rand -base64 32
```

#### 2.3 Configurar usuário padrão (opcional)

No mesmo arquivo `uptrace.yml`, procure a seção `seed_data` para personalizar o usuário admin:

```yaml
seed_data:
  users:
    - key: user1 # Altere aqui
      name: Admin # Altere aqui
      email: admin@seu-dominio.com  # Altere aqui
      password: SuaSenhaSegura       # Altere aqui
      email_confirmed: true
```

### Passo 3: Configurar o Nginx

#### 3.1 Editar configuração do Nginx

```bash
nano nginx/nginx.conf
```

**Atualize o `server_name` com seu domínio:**

```nginx
# Procure por "server_name" e altere:
server_name seu-dominio.com;  # Substitua pelo seu domínio real
```

**Exemplo completo da seção server:**

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name uptrace.exemplo.com www.uptrace.exemplo.com;  # ← ALTERE AQUI
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    
    server_name uptrace.exemplo.com www.uptrace.exemplo.com;  # ← ALTERE AQUI
    
    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    
    # ... resto da configuração
}
```

### Passo 4: Configurar SSL/TLS com Let's Encrypt

#### 4.1 Executar script de configuração SSL

```bash
# Tornar o script executável
chmod +x setup-ssl.sh

# Executar como root
sudo ./setup-ssl.sh
```

O script irá solicitar:
- **Domínio**: Digite seu domínio completo (ex: `uptrace.exemplo.com`)
- **Email**: Digite seu email (usado pelo Let's Encrypt)
- **Modo teste**: Digite `s` na primeira vez para testar

**Primeira execução (TESTE):**
```bash
sudo ./setup-ssl.sh
# Digite seu domínio: uptrace.exemplo.com
# Digite seu email: seu@email.com
# Usar certificado de TESTE? [s/N]: s
```

Se tudo funcionar, execute novamente em **modo PRODUÇÃO**:

```bash
sudo ./setup-ssl.sh
# Digite seu domínio: uptrace.exemplo.com
# Digite seu email: seu@email.com
# Usar certificado de TESTE? [s/N]: n
```

#### 4.2 Verificar certificados gerados

```bash
# Verificar arquivos
ls -lh nginx/ssl/

# Deve mostrar:
# server.crt  (certificado)
# server.key  (chave privada)

# Verificar validade
openssl x509 -in nginx/ssl/server.crt -noout -dates
```

### Passo 5: Iniciar os serviços

```bash
# Subir todos os containers
docker compose up -d

# Verificar status
docker compose ps

# Ver logs
docker compose logs -f
```

Aguarde cerca de 30-60 segundos para todos os serviços iniciarem completamente.

### Passo 6: Acessar o Uptrace

Abra seu navegador e acesse:

```
https://seu-dominio.com
```

**Credenciais padrão:**
- **Email**: `admin@uptrace.local` (ou o que você configurou)
- **Senha**: `admin` (ou a que você configurou)

⚠️ **IMPORTANTE**: Altere a senha após o primeiro login!

---

## 🔐 Configuração SSL/TLS

### Certificados Let's Encrypt

Os certificados são gerados automaticamente pelo script `create-ssl.sh`.

#### Renovação Automática

A renovação é configurada automaticamente via **cron**. Os certificados são renovados diariamente às 3h da manhã.

Verificar cron job:
```bash
sudo crontab -l | grep renew-ssl
```

#### Renovação Manual

Se necessário, renove manualmente:

```bash
# Usando o script automático
sudo ./renew-ssl-manual.sh

# Ou manualmente
sudo certbot renew
sudo cp /etc/letsencrypt/live/seu-dominio.com/fullchain.pem nginx/ssl/server.crt
sudo cp /etc/letsencrypt/live/seu-dominio.com/privkey.pem nginx/ssl/server.key
docker compose restart nginx
```

#### Verificar validade do certificado

```bash
# Via openssl
openssl x509 -in nginx/ssl/server.crt -noout -dates

# Via curl
curl -vI https://seu-dominio.com 2>&1 | grep -i expire

# Online (recomendado)
# Acesse: https://www.ssllabs.com/ssltest/
```

---

## 🚀 Uso

### Enviar dados de telemetria

Configure suas aplicações para enviar dados OTLP para o Uptrace:

#### Node.js

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'https://seu-dominio.com:4317',
    headers: {
      'uptrace-dsn': 'https://project_token@seu-dominio.com?grpc=4317'
    }
  })
});

sdk.start();
```

#### Python

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider())

otlp_exporter = OTLPSpanExporter(
    endpoint="https://seu-dominio.com:4317",
    headers=(("uptrace-dsn", "https://project_token@seu-dominio.com?grpc=4317"),)
)

trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)
```

#### Go

```go
import (
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
)

exporter, _ := otlptracegrpc.New(
    context.Background(),
    otlptracegrpc.WithEndpoint("seu-dominio.com:4317"),
    otlptracegrpc.WithHeaders(map[string]string{
        "uptrace-dsn": "https://project_token@seu-dominio.com?grpc=4317",
    }),
)

tp := trace.NewTracerProvider(
    trace.WithBatcher(exporter),
)
```

### Obter token do projeto

1. Acesse o Uptrace: `https://seu-dominio.com`
2. Faça login
3. Vá em **Projects** → Seu projeto → **Settings**
4. Copie o **DSN** (Data Source Name)

---

## 🔧 Manutenção

### Comandos úteis do Docker Compose

```bash
# Ver logs de todos os serviços
docker compose logs -f

# Ver logs de um serviço específico
docker compose logs -f uptrace
docker compose logs -f nginx

# Reiniciar um serviço
docker compose restart uptrace

# Parar todos os serviços
docker compose down

# Parar e remover volumes (⚠️ APAGA DADOS!)
docker compose down -v

# Atualizar imagens
docker compose pull
docker compose up -d
```

### Backup

#### Backup dos dados

```bash
# Backup do ClickHouse
docker compose exec clickhouse clickhouse-client --query "BACKUP DATABASE uptrace TO Disk('backups', 'backup-$(date +%Y%m%d).zip')"

# Backup do PostgreSQL
docker compose exec postgres pg_dump -U uptrace uptrace > backup-postgres-$(date +%Y%m%d).sql

# Backup dos volumes Docker
docker run --rm -v observability_ch_data:/data -v $(pwd)/backups:/backup alpine tar czf /backup/clickhouse-$(date +%Y%m%d).tar.gz /data
docker run --rm -v observability_pg_data3:/data -v $(pwd)/backups:/backup alpine tar czf /backup/postgres-$(date +%Y%m%d).tar.gz /data
```

#### Backup dos certificados

```bash
# Backup dos certificados SSL
sudo tar czf ssl-backup-$(date +%Y%m%d).tar.gz /etc/letsencrypt nginx/ssl/
```

### Atualização do Uptrace

```bash
# Parar serviços
docker compose down

# Atualizar imagem no docker compose.yml
# Exemplo: image: "uptrace/uptrace:2.1.0"

# Baixar nova imagem
docker compose pull uptrace

# Subir novamente
docker compose up -d

# Verificar logs
docker compose logs -f uptrace
```

### Monitoramento

```bash
# Uso de recursos
docker stats

# Status dos containers
docker compose ps

# Health checks
docker compose ps | grep healthy
```

---

## 🐛 Troubleshooting

### Problema: Erro CORS no navegador

**Sintoma:**
```
Cross-Origin Request Blocked: The Same Origin Policy disallows...
```

**Solução:**
1. Verifique se o `site.url` no `uptrace.yml` corresponde à URL que você acessa
2. Certifique-se de que o Nginx tem os headers CORS configurados
3. Reinicie os serviços:
```bash
docker compose restart uptrace nginx
```

### Problema: Certificado SSL inválido

**Sintoma:**
```
NET::ERR_CERT_AUTHORITY_INVALID
```

**Solução:**
1. Verifique se gerou o certificado em modo produção (não teste):
```bash
sudo ./setup-ssl.sh
# Usar certificado de TESTE? [s/N]: n  ← Digite 'n'
```

2. Verifique se o domínio aponta para o servidor:
```bash
dig +short seu-dominio.com
```

### Problema: Uptrace não inicia

**Sintoma:**
```
uptrace exited with code 1
```

**Solução:**
1. Ver logs detalhados:
```bash
docker compose logs uptrace
```

2. Verificar se ClickHouse e PostgreSQL estão rodando:
```bash
docker compose ps clickhouse postgres
```

3. Verificar configuração do `uptrace.yml`:
```bash
# Testar sintaxe YAML
python3 -c "import yaml; yaml.safe_load(open('uptrace.yml'))"
```

### Problema: Nginx não inicia

**Sintoma:**
```
nginx: [emerg] host not found in upstream "uptrace:80"
```

**Solução:**
1. Certifique-se de que todos os serviços estão na mesma rede Docker
2. Verifique a configuração do Nginx:
```bash
docker compose exec nginx nginx -t
```

3. Reinicie na ordem correta:
```bash
docker compose down
docker compose up -d
```

### Problema: Porta 80 ou 443 já em uso

**Sintoma:**
```
Error starting userland proxy: listen tcp 0.0.0.0:80: bind: address already in use
```

**Solução:**
1. Identificar o processo usando a porta:
```bash
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443
```

2. Parar o serviço conflitante:
```bash
# Se for Apache
sudo systemctl stop apache2

# Se for outro Nginx
sudo systemctl stop nginx
```

### Problema: Certificado não renova automaticamente

**Solução:**
1. Verificar cron job:
```bash
sudo crontab -l | grep renew-ssl
```

2. Testar renovação manual:
```bash
sudo certbot renew --dry-run
```

3. Verificar logs de renovação:
```bash
cat ssl-renew.log
sudo journalctl -u certbot
```

---

## 📁 Estrutura do Projeto

```
observability/
├── README.md                    # Este arquivo
├── docker compose.yml           # Orquestração dos containers
├── uptrace.yml                  # Configuração do Uptrace
├── example-uptrace.yml          # Arquivo de exemplo
├── .env                         # Variáveis de ambiente (criar se necessário)
├── .gitignore                   # Arquivos ignorados pelo git
│
├── nginx/                       # Configurações do Nginx
│   ├── nginx.conf              # Configuração principal
│
├── certs/                       # Certificados do Uptrace (opcional)
│   ├── server.crt
│   └── server.key
│
├── scripts/                     # Scripts de automação
│   ├── setup-ssl.sh            # Configuração inicial SSL
│   ├── renew-ssl.sh            # Renovação automática
│   └── renew-ssl-manual.sh     # Renovação manual
│
└── backups/                     # Backups (criar se necessário)
    ├── clickhouse-*.tar.gz
    └── postgres-*.sql
```

---

## 🔒 Segurança

### Checklist de Segurança

- [ ] Certificado SSL/TLS válido instalado
- [ ] Senha do admin alterada
- [ ] Secret do `uptrace.yml` alterado para valor aleatório
- [ ] Senhas dos bancos de dados alteradas (produção)
- [ ] Firewall configurado (portas 80, 443, 4317)
- [ ] Backup automático configurado
- [ ] Renovação automática de certificados ativa
- [ ] HTTPS forçado (redirect HTTP → HTTPS)
- [ ] Headers de segurança configurados no Nginx

## 📚 Recursos

- [Documentação Oficial do Uptrace](https://uptrace.dev/get/get-started.html)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [Nginx Documentation](https://nginx.org/en/docs/)

---

## 🤝 Contribuindo

Encontrou um problema ou tem sugestões? Abra uma issue ou pull request!

---

## 📄 Licença

Este projeto utiliza componentes open source:
- **Uptrace**: BSL (Business Source License)
- **ClickHouse**: Apache License 2.0
- **PostgreSQL**: PostgreSQL License
- **Redis**: BSD License
- **Nginx**: BSD-2-Clause License

---

## 📞 Suporte

Se precisar de ajuda:

1. Consulte a seção [Troubleshooting](#troubleshooting)
2. Verifique os logs: `docker compose logs -f`
3. Consulte a documentação oficial
4. Abra uma issue no repositório

---

**Desenvolvidopor BrainyLab**

*Última atualização: Dezembro 2025*
