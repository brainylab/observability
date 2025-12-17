# ⚡ Quick Start - SSL Multi-Domínio

Guia rápido para configurar SSL com Let's Encrypt para domínios separados (UI + Ingest).

---

## 📋 Pré-requisitos

- 2 domínios apontando para o servidor (ex: `uptrace.exemplo.com` e `ingest.exemplo.com`)
- Portas 80, 443 e 4317 abertas

---

## 🚀 Configuração em 5 passos

### 1️⃣ Configurar DNS

```bash
# Verificar se DNS está apontando corretamente
dig +short uptrace.exemplo.com  # Deve retornar IP do servidor
dig +short ingest.exemplo.com   # Deve retornar IP do servidor
```

---

### 2️⃣ Renomear e configurar uptrace.yml

```bash
# Renomear arquivo de exemplo
mv example-uptrace.yml uptrace.yml

# Editar configurações
nano uptrace.yml
```

**Alterar as seguintes linhas:**

```yaml
service:
  secret: $(openssl rand -base64 32)  # Gerar secret aleatório

site:
  url: https://uptrace.exemplo.com
  ingest_url: https://ingest.exemplo.com?grpc=4317
```

---

### 3️⃣ Configurar domínios no nginx.conf

```bash
# Editar configuração do Nginx
nano nginx/nginx.conf
```

**Substituir em TODOS os lugares:**

```nginx
# ANTES:
server_name seu-dominio.com;

# DEPOIS - UI (3 ocorrências):
server_name uptrace.exemplo.com;

# DEPOIS - Ingest (3 ocorrências):
server_name ingest.exemplo.com;
```

**Locais para alterar:**
- Linha ~23: HTTP redirect UI
- Linha ~53: HTTPS UI
- Linha ~115: HTTP redirect Ingest
- Linha ~130: HTTPS Ingest
- Linha ~177: gRPC Ingest

---

### 4️⃣ Executar script de SSL

```bash
# Tornar executável
chmod +x setup-ssl.sh

# PRIMEIRA VEZ (modo teste)
sudo ./setup-ssl.sh
# Digite domínio UI: uptrace.exemplo.com
# Digite domínio Ingest: ingest.exemplo.com
# Digite email: seu@email.com
# Usar certificado de TESTE? [s/N]: s

# Se funcionou, execute em PRODUÇÃO
sudo ./setup-ssl.sh
# ... (mesmas perguntas)
# Usar certificado de TESTE? [s/N]: n  ← Modo PRODUÇÃO
```

---

### 5️⃣ Iniciar serviços

```bash
# Subir todos os containers
docker-compose up -d

# Aguardar inicialização (30-60 segundos)
sleep 30

# Verificar status
docker-compose ps

# Ver logs
docker-compose logs -f
```

---

## ✅ Verificação

### Testar endpoints

```bash
# UI
curl -I https://uptrace.exemplo.com
# Deve retornar: HTTP/2 200

# Ingest HTTP
curl -I https://ingest.exemplo.com
# Deve retornar: HTTP/2 200

# Logs
docker-compose logs nginx uptrace
```

### Acessar interface

```
URL: https://uptrace.exemplo.com
Usuário: admin@uptrace.local
Senha: admin
```

⚠️ **Altere a senha após primeiro login!**

---

## 🔧 Comandos Úteis

### Gerenciar containers

```bash
# Ver logs
docker-compose logs -f uptrace
docker-compose logs -f nginx

# Reiniciar serviço
docker-compose restart nginx
docker-compose restart uptrace

# Parar todos
docker-compose down

# Parar e remover volumes (⚠️ APAGA DADOS!)
docker-compose down -v
```

### Verificar certificados

```bash
# Validade dos certificados
openssl x509 -in nginx/ssl/server.crt -noout -dates
openssl x509 -in nginx/ssl/ingest.crt -noout -dates

# Verificar domínios
openssl x509 -in nginx/ssl/server.crt -noout -subject
openssl x509 -in nginx/ssl/ingest.crt -noout -subject
```

### Renovar certificados

```bash
# Renovação manual
sudo ./renew-ssl-manual.sh

# Testar renovação (dry-run)
sudo certbot renew --dry-run

# Ver logs de renovação automática
tail -f ssl-renew.log
```

---

## 📊 Estrutura de Arquivos

```
observability/
├── docker-compose.yml           # Orquestração
├── uptrace.yml                  # Config Uptrace (criar do example)
├── example-uptrace.yml          # Arquivo de exemplo
├── setup-ssl.sh                 # Script de SSL ⭐
├── renew-ssl-manual.sh          # Renovação manual
├── nginx/
│   ├── nginx.conf              # Config Nginx (editar domínios)
│   └── ssl/
│       ├── server.crt          # Cert UI (auto-gerado)
│       ├── server.key          # Key UI (auto-gerado)
│       ├── ingest.crt          # Cert Ingest (auto-gerado)
│       └── ingest.key          # Key Ingest (auto-gerado)
└── README.md                    # Documentação completa
```

---

## 🐛 Problemas Comuns

### DNS não resolve

```bash
# Verificar propagação
dig +short uptrace.exemplo.com
dig +short ingest.exemplo.com

# Aguardar 5-10 minutos e tentar novamente
```

### Porta 80 em uso

```bash
# Identificar processo
sudo netstat -tlnp | grep :80

# Parar Apache/Nginx do sistema
sudo systemctl stop apache2
sudo systemctl stop nginx
```

### Certificado inválido

```bash
# Verificar se gerou em modo produção
openssl x509 -in nginx/ssl/server.crt -noout -issuer

# Deve mostrar: "Let's Encrypt"
# Se mostrar "Fake LE", foi gerado em modo teste
# Solução: Re-executar setup-ssl.sh em modo produção (n)
```

### Nginx não inicia

```bash
# Testar configuração
docker-compose exec nginx nginx -t

# Ver erros
docker-compose logs nginx

# Verificar se domínios estão corretos no nginx.conf
grep "server_name" nginx/nginx.conf
```

### CORS errors no browser

```bash
# Verificar se URLs no uptrace.yml correspondem ao que você acessa
grep -A2 "site:" uptrace.yml

# Deve ser exatamente o que você digita no navegador
# Exemplo: https://uptrace.exemplo.com (não http, não localhost)

# Reiniciar após alterar
docker-compose restart uptrace nginx
```

---

## 🔄 Fluxo de Dados

```
Cliente/App
    │
    ├─→ HTTPS:443 ────→ Nginx ────→ Uptrace:80 (UI)
    │                     │
    └─→ HTTPS:443 ────────┘         
        (ingest.exemplo.com)
    │
    └─→ gRPC:4317 ────→ Nginx ────→ Uptrace:4317 (OTLP)
        (ingest.exemplo.com)
```

---

## 📚 Documentação Completa

- **README.md** - Documentação completa do projeto
- **SSL-SETUP-GUIDE.md** - Guia detalhado de SSL
- **QUICK-START.md** - Este arquivo (comandos rápidos)

---

## 🆘 Precisa de Ajuda?

1. Consulte **README.md** seção Troubleshooting
2. Verifique logs: `docker-compose logs -f`
3. Teste certificados: `openssl x509 -in nginx/ssl/server.crt -noout -text`
4. Valide SSL online: https://www.ssllabs.com/ssltest/

---

## ✨ Pronto!

Agora você tem:
- ✅ SSL válido com Let's Encrypt
- ✅ UI em `https://uptrace.exemplo.com`
- ✅ Ingestão em `https://ingest.exemplo.com`
- ✅ gRPC em `ingest.exemplo.com:4317`
- ✅ Renovação automática configurada

**Próximos passos:**
1. Alterar senha do admin
2. Criar projeto no Uptrace
3. Configurar aplicações para enviar telemetria

---

**Desenvolvido com ❤️ para BrainyLab**