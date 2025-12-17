# 📑 Índice de Documentação - Observability Stack

**Bem-vindo ao guia completo de configuração do Uptrace com SSL multi-domínio!**

Este índice te ajuda a navegar pela documentação e encontrar rapidamente o que precisa.

---

## 🚀 Por onde começar?

### Primeira instalação
1. **[QUICK-START.md](QUICK-START.md)** ⚡ - Comece aqui! Configuração em 5 passos
2. **[validate-setup.sh](validate-setup.sh)** 🔍 - Execute antes do setup para validar
3. **[setup-ssl.sh](setup-ssl.sh)** 🔐 - Script de configuração SSL

### Já instalado, preciso de ajuda
- **[SUMMARY.md](SUMMARY.md)** 📊 - Visão geral e diagramas
- **[SSL-SETUP-GUIDE.md](SSL-SETUP-GUIDE.md)** 🔒 - Troubleshooting SSL
- **[README.md](README.md)** 📚 - Documentação completa

---

## 📚 Documentação

| Arquivo | Descrição | Quando usar |
|---------|-----------|-------------|
| **[QUICK-START.md](QUICK-START.md)** | Guia rápido em 5 passos | Primeira instalação |
| **[README.md](README.md)** | Documentação completa | Referência completa |
| **[SSL-SETUP-GUIDE.md](SSL-SETUP-GUIDE.md)** | Guia SSL detalhado | Problemas com SSL/certificados |
| **[SUMMARY.md](SUMMARY.md)** | Resumo visual | Visão geral da arquitetura |
| **[FILES-CREATED.md](FILES-CREATED.md)** | Lista de arquivos | Entender estrutura do projeto |
| **[INDEX.md](INDEX.md)** | Este arquivo | Navegação |

---

## 🔧 Scripts

| Script | Descrição | Uso |
|--------|-----------|-----|
| **[validate-setup.sh](validate-setup.sh)** | Validação pré-setup | `./validate-setup.sh` |
| **[setup-ssl.sh](setup-ssl.sh)** | Setup SSL inicial | `sudo ./setup-ssl.sh` |
| **[renew-ssl-manual.sh](renew-ssl-manual.sh)** | Renovação manual | `sudo ./renew-ssl-manual.sh` |
| `renew-ssl-multi.sh` | Renovação automática | Criado pelo setup |

---

## 📖 Guias por Tarefa

### Configuração Inicial

1. **Preparar ambiente**
   - Leia: [QUICK-START.md - Pré-requisitos](QUICK-START.md#📋-pré-requisitos)
   - Configure DNS (A records)
   - Abra portas no firewall

2. **Configurar arquivos**
   - Leia: [QUICK-START.md - Passo 2](QUICK-START.md#2️⃣-renomear-e-configurar-uptraceyml)
   - Renomeie `example-uptrace.yml` → `uptrace.yml`
   - Edite `uptrace.yml` (url, ingest_url, secret)
   - Edite `nginx/nginx.conf` (domínios)

3. **Validar configuração**
   - Execute: `./validate-setup.sh`
   - Corrija erros encontrados

4. **Executar setup SSL**
   - Leia: [SSL-SETUP-GUIDE.md - Passo a Passo](SSL-SETUP-GUIDE.md#📝-passo-a-passo)
   - Execute: `sudo ./setup-ssl.sh`
   - Modo TESTE primeiro, depois PRODUÇÃO

5. **Iniciar serviços**
   - Execute: `docker-compose up -d`
   - Acesse: `https://seu-dominio.com`

### Solução de Problemas

| Problema | Consulte |
|----------|----------|
| Certificado inválido | [SSL-SETUP-GUIDE.md - Problema: Certificado não é válido](SSL-SETUP-GUIDE.md#problema-certificado-não-é-válido) |
| DNS não resolve | [SSL-SETUP-GUIDE.md - Problema: DNS não resolve](SSL-SETUP-GUIDE.md#problema-dns-não-resolve) |
| Porta em uso | [QUICK-START.md - Porta 80 em uso](QUICK-START.md#porta-80-em-uso) |
| CORS errors | [README.md - Erro CORS](README.md#problema-erro-cors-no-navegador) |
| Nginx não inicia | [README.md - Nginx não inicia](README.md#problema-nginx-não-inicia) |

### Manutenção

| Tarefa | Documentação |
|--------|--------------|
| Renovar certificados | [SSL-SETUP-GUIDE.md - Renovação](SSL-SETUP-GUIDE.md#🔄-renovação-de-certificados) |
| Backup | [README.md - Backup](README.md#backup) |
| Atualizar Uptrace | [README.md - Atualização](README.md#atualização-do-uptrace) |
| Monitorar | [README.md - Monitoramento](README.md#monitoramento) |

### Integração com Apps

| Linguagem | Documentação |
|-----------|--------------|
| Node.js | [README.md - Node.js](README.md#nodejs) |
| Python | [README.md - Python](README.md#python) |
| Go | [README.md - Go](README.md#go) |
| Outros | [OpenTelemetry Docs](https://opentelemetry.io/docs/) |

---

## 🔍 Busca Rápida

### Por Tópico

- **SSL/TLS**: [SSL-SETUP-GUIDE.md](SSL-SETUP-GUIDE.md)
- **DNS**: [SSL-SETUP-GUIDE.md - Configurar DNS](SSL-SETUP-GUIDE.md#1-configurar-dns)
- **Domínios**: [SUMMARY.md - Arquitetura](SUMMARY.md#🏗️-arquitetura-multi-domínio)
- **Certificados**: [README.md - Certificados](README.md#certificados-lets-encrypt)
- **Docker**: [README.md - Docker Compose](README.md#comandos-úteis-do-docker-compose)
- **Nginx**: [README.md - Configuração Nginx](README.md#3-configurar-o-nginx)
- **Uptrace**: [README.md - Configurar Uptrace](README.md#2-configurar-o-uptrace)
- **Firewall**: [SSL-SETUP-GUIDE.md - Pré-requisitos](SSL-SETUP-GUIDE.md#pré-requisitos)
- **Backup**: [README.md - Backup](README.md#backup)
- **Segurança**: [README.md - Segurança](README.md#🔒-segurança)

### Por Comando

```bash
# Validar setup
./validate-setup.sh

# Configurar SSL
sudo ./setup-ssl.sh

# Renovar SSL
sudo ./renew-ssl-manual.sh

# Iniciar serviços
docker-compose up -d

# Ver logs
docker-compose logs -f

# Parar serviços
docker-compose down

# Reiniciar
docker-compose restart nginx uptrace

# Verificar certificado
openssl x509 -in nginx/ssl/server.crt -noout -dates
```

---

## 🎯 Fluxo de Trabalho Recomendado

```
1. Leia QUICK-START.md
   ↓
2. Configure DNS
   ↓
3. Edite nginx.conf e uptrace.yml
   ↓
4. Execute ./validate-setup.sh
   ↓
5. Corrija erros (se houver)
   ↓
6. Execute sudo ./setup-ssl.sh (TESTE)
   ↓
7. Se OK, execute sudo ./setup-ssl.sh (PRODUÇÃO)
   ↓
8. Execute docker-compose up -d
   ↓
9. Acesse https://seu-dominio.com
   ↓
10. Configure suas aplicações
```

---

## 📞 Precisa de Ajuda?

1. **Verifique a documentação relevante** (use este índice)
2. **Execute o script de validação**: `./validate-setup.sh`
3. **Consulte os logs**: `docker-compose logs -f`
4. **Procure na seção Troubleshooting**: [README.md](README.md#🐛-troubleshooting)

---

## 📊 Arquitetura do Sistema

```
Cliente
  ↓
Nginx (SSL Termination)
  ├─→ UI: https://uptrace.dominio.com
  └─→ Ingest: https://ingest.dominio.com + :4317
       ↓
     Uptrace
       ├─→ ClickHouse (dados)
       ├─→ PostgreSQL (metadados)
       └─→ Redis (cache)
```

Diagrama completo: [SUMMARY.md - Arquitetura](SUMMARY.md#🏗️-arquitetura-multi-domínio)

---

## ✅ Checklist Rápido

Antes de começar:
- [ ] DNS configurado
- [ ] Portas abertas (80, 443, 4317)
- [ ] Docker instalado
- [ ] nginx.conf editado
- [ ] uptrace.yml editado
- [ ] `./validate-setup.sh` executado

---

**Desenvolvido com ❤️ para BrainyLab**

*Última atualização: Dezembro 2025*
