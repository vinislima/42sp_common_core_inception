Inception · 42SP · login vinda-si

# Diário completo do projeto

Tudo que construímos, testamos e corrigimos — em linguagem simples, com o motivo de cada decisão e o arquivo exato onde ela mora no repositório.

Repositório: Vogsphere (\~/inception) Stack: NGINX + WordPress/php-fpm + MariaDB Base: debian:bookworm

[Visão geral](#visao-geral) [Roteiro da régua](#roteiro-regua) [Estrutura](#estrutura) [Arquivos](#arquivos) [Antes do make](#config-pre-make) [Montagem da VM](#vm) [Bugs reais](#bugs) [Os 10 testes](#testes) [Perguntas/defesa](#defesa) [Checklist final](#checklist)

00

## Visão geral

O que o projeto pede e o que construímos pra responder a isso.

O subject do Inception pede uma pequena infraestrutura web rodando inteiramente dentro de uma **máquina virtual**, orquestrada por **Docker Compose**, com três serviços, cada um no seu próprio container, cada um com seu próprio `Dockerfile` escrito do zero (nada de imagem pronta do Docker Hub, exceto a base Debian/Alpine):

| Container | Função | Particularidade exigida |
| --- | --- | --- |
| `nginx` | único ponto de entrada do sistema todo | só porta 443, só TLS 1.2/1.3 |
| `wordpress` | o site (CMS) + `php-fpm` | sem NGINX dentro, instalação 100% automática |
| `mariadb` | banco de dados do WordPress | sem NGINX dentro, dados persistidos em volume |

Os três se enxergam por uma **rede Docker** dedicada (chamada `inception`) e dois **volumes Docker** guardam os dados fora dos containers, apontando pra `/home/vinda-si/data/` no disco da VM — assim, apagar ou reconstruir um container nunca apaga o conteúdo do site ou do banco.

01

## Roteiro oficial: a régua, ponto a ponto

Na mesma ordem em que a régua de avaliação apresenta os itens, cruzada com o subject. Pra cada ponto: o conceito, a decisão que tomamos, onde está implementado, e o comando de verificação (com o que ele faz).

### A · Preliminaries

Só o botão "Cheat" do avaliador, pra reportar suspeita de fraude — encerra a avaliação com nota -42. Não há nada a preparar aqui além de garantir que o trabalho é seu, de fato.

### B · Preliminary tests

*"the use of a local .env file... and/or docker secrets \[is\] allowed... any credentials outside of secrets files... evaluation stops and the mark is 0."*

Por isso `secrets/*.txt` e `srcs/.env` existem, mas **fora** do git (ver capítulo 04). Antes da defesa, confirmamos isso com:

```
git log --all -p | grep -iE "password|secret" | grep -v "\.example"
```

O que o comando faz: `git log --all -p` mostra o histórico completo com o conteúdo de cada mudança (`-p` = patch); o `grep` filtra linhas que mencionem senha ou segredo; o segundo `grep -v` remove os resultados que são só os arquivos `.example` (modelos, sem senha real). Se sobrar alguma linha com uma senha de verdade, é motivo de nota zero.

*"you have to clone their Git repository on their station."* — o repositório que vale é o do **Vogsphere** (Gitea da 42), clonado dentro da própria VM (capítulo 05).

### C · General instructions

*"srcs folder... at the root... a Makefile... at the root"* — estrutura do capítulo 02.

Antes de qualquer teste, o avaliador roda o comando de limpeza (e, na versão mais recente da régua, mais uma linha):

```
docker stop $(docker ps -qa)
docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
sudo rm -rf /home/vinda-si/data/*
```

Linha a linha: `docker stop` para todos os containers (rodando ou já parados, `-qa` = quiet + all); `docker rm` remove os containers parados; `docker rmi -f` apaga todas as imagens, forçado (`-f`), mesmo se algo ainda referenciar; `docker volume rm` apaga todos os volumes nomeados; `docker network rm` remove as redes customizadas (as três padrão do Docker — bridge/host/none — são protegidas e não saem, por isso o `2>/dev/null` silencia o erro delas); a última linha apaga o conteúdo persistido no host. Resultado: zero resíduo de qualquer tentativa anterior — exatamente o estado que simulamos nos capítulos 04 e 05 antes de cada bateria de testes.

Depois disso, a régua examina o `docker-compose.yml` e os Dockerfiles procurando por proibições (`network: host`, `links:`, `--link`, `tail -f`, processo em background, versão errada de imagem base, loop infinito) — tudo isso está detalhado no capítulo 03 (bugs) e verificado no capítulo 07 (testes 2 e 3). Por fim, roda o Makefile:

```
make
```

Builda as 3 imagens e sobe os 3 containers via `docker compose`, sem crash — se isso falhar aqui, a avaliação já para.

### D · Mandatory part — Activity overview

4 perguntas conceituais que você explica **verbalmente** pro avaliador: como Docker/compose funcionam, imagem com vs. sem compose, benefício do Docker vs. VMs, pertinência da estrutura de diretórios. Respostas completas no capítulo 09 (Perguntas e defesa) — essa seção da régua não tem comando pra rodar, é só conversa.

### E · README check

*"first line... italicized... Description, Instructions, Resources (with explanation of how AI was used)"*

Implementado em README.md. Verificação:

```
head -1 README.md
grep -E "^## " README.md
```

`head -1` mostra só a primeira linha do arquivo (confirma o formato/itálico exato); `grep -E "^## "` lista todo título de seção de nível 2 (confirma que Description, Instructions e Resources existem).

### F · Documentation check

*"USER_DOC.md and DEV_DOC.md... if missing or empty, the review ends now."*

```
wc -l USER_DOC.md DEV_DOC.md
```

`wc -l` conta linhas de cada arquivo — confirma que existem **e** não estão vazios (0 linhas seria reprovação na hora).

### G · Simple setup

*"NGINX accessed by port 443 only... SSL/TLS certificate... WordPress properly installed (no installation page)... shouldn't be accessible via http"*

É o resumo de alto nível do que vem a seguir — mas já dá pra conferir os três pontos agora mesmo, direto.

#### 1. Conferir a porta

```
docker compose -f srcs/docker-compose.yml ps
ss -tlnp | grep -E ':443|:80'
```

O `docker compose ps` mostra, na coluna `PORTS`, exatamente quais portas do host foram mapeadas pra cada container — só o `nginx` deve aparecer com `0.0.0.0:443->443/tcp`; `wordpress` e `mariadb` não devem ter nenhuma porta mapeada (só são alcançáveis de dentro da rede Docker). O `ss -tlnp` confere isso no nível do próprio sistema operacional da VM: `-t` = TCP, `-l` = só o que está "escutando" (listening), `-n` = mostra números de porta em vez de tentar resolver nome, `-p` = mostra qual processo dono da porta. Só a 443 deve aparecer na lista.

#### 2. O que é um certificado TLS/SSL e como funciona (resumo)

É um "crachá digital": um arquivo que liga uma **chave pública** a uma identidade (no nosso caso, o domínio `vinda-si.42.fr`), junto com um prazo de validade. Quando o navegador conecta, acontece um *handshake*: servidor e cliente usam essa chave pra combinar, com segurança, uma chave de sessão temporária — e é essa chave de sessão que criptografa o tráfego dali em diante. Um certificado **autoassinado** (o nosso) garante a criptografia normalmente, só não tem um terceiro confiável (uma Autoridade Certificadora reconhecida, tipo Let's Encrypt) atestando que o domínio é "quem diz ser" — por isso o navegador mostra o aviso, mas o subject aceita isso explicitamente.

#### 3. Conferir o certificado na prática

```
echo | openssl s_client -connect vinda-si.42.fr:443 -tls1_2 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates
```

`openssl s_client` faz uma conexão TLS de teste (como um navegador faria) e imprime o certificado recebido; o `echo |` no início só fecha a conexão sozinha sem precisar digitar nada. O segundo `openssl x509` pega esse certificado e extrai, sem mais nada (`-noout`): `-subject` (pra quem foi emitido — deve mostrar `CN=vinda-si.42.fr`), `-issuer` (quem emitiu — no autoassinado, é o mesmo que o subject) e `-dates` (validade). Gerado em build-time no `srcs/requirements/nginx/Dockerfile`.

#### 4. Conferir se o WordPress está instalado de verdade

```
docker compose -f srcs/docker-compose.yml exec wordpress wp core is-installed --allow-root; echo $?
```

`wp core is-installed` é um comando do wp-cli que não imprime nada — só retorna um código de saída: `0` (sucesso) se o WordPress já foi instalado e configurado, `1` se ainda não. O `echo $?` imprime esse código na tela. Complementar: abrir `https://vinda-si.42.fr` no navegador tem que mostrar o site de verdade (posts, tema) — nunca a tela "Welcome"/"Bem-vindo" de instalação do WordPress.

### H · Docker Basics

*"one Dockerfile per service... not empty... own Dockerfiles... forbidden to use ready-made ones... penultimate stable version... image name = service name... via docker compose, no crash"*

```
ls -la srcs/requirements/*/Dockerfile
grep -H "^FROM" srcs/requirements/*/Dockerfile
docker images | grep inception
```

`ls -la` confirma os 3 arquivos existindo com tamanho > 0; `grep -H "^FROM"` mostra, com o nome do arquivo (`-H`), qual imagem cada Dockerfile usa como base — tem que ser `debian:bookworm`, nunca `latest` nem outra imagem pronta; `docker images | grep inception` lista as imagens construídas, confirmando que o nome bate com o do serviço. Implementado em `srcs/requirements/<serviço>/Dockerfile` (detalhes no capítulo 02).

### I · Docker Network

*"docker-network is used... docker network ls... simple explanation"*

```
docker network ls | grep inception
docker network inspect srcs_inception --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
```

O primeiro lista as redes Docker existentes, filtrando pela nossa; o segundo entra nos detalhes dessa rede e imprime, formatado, só o nome de cada container conectado nela — confirma que os 3 (nginx, wordpress, mariadb) estão todos na mesma rede. Implementado em `srcs/docker-compose.yml`, bloco `networks:`. Explicação verbal no capítulo 09.

### J · NGINX with SSL/TLS

*"Dockerfile exists... container created... http fails... https shows the real WordPress site... TLS 1.2/1.3 demonstrated"*

```
curl -v http://vinda-si.42.fr
curl -v --tlsv1.2 --tls-max 1.2 https://vinda-si.42.fr -k
curl -v --tlsv1.1 --tls-max 1.1 https://vinda-si.42.fr -k
```

`-v` mostra o processo de conexão completo; o primeiro comando tem que terminar em "Connection refused" (porta 80 nem está aberta); o segundo força TLS 1.2 e tem que conectar, mostrando o certificado; o terceiro força TLS 1.1 (não suportado por nós de propósito) e tem que falhar — prova que só 1.2/1.3 funcionam, não é coincidência. Implementado em `srcs/requirements/nginx/conf/nginx.conf.template` (`ssl_protocols TLSv1.2 TLSv1.3;`, sem bloco de porta 80 em lugar nenhum).

### K · WordPress with php-fpm and its volume

*"no NGINX in the Dockerfile... Volume... path '/home/login/data/'... add a comment... admin username must not include 'admin'... edit a page, verify on the website"*

```
grep -i nginx srcs/requirements/wordpress/Dockerfile
docker compose exec wordpress wp user list --allow-root
docker volume inspect srcs_wp_data
```

O `grep` confirma ausência de NGINX no Dockerfile do WordPress; `wp user list` (rodado dentro do próprio container, via `docker compose exec`) lista os usuários e seus *roles* — confere visualmente que o login do administrator não contém "admin"; `docker volume inspect` mostra, no campo `Options.device`, o caminho exato `/home/vinda-si/data/wordpress`. O comentário e a edição de página são feitos de verdade no navegador, logado como cada usuário. Implementado em `srcs/requirements/wordpress/tools/entrypoint.sh`.

### L · MariaDB and its volume

*"no NGINX... Volume... path '/home/login/data/'... explain how to login... database is not empty"*

```
docker volume inspect srcs_wp_db
docker compose exec mariadb mariadb -u root -p -e "SHOW DATABASES; USE wordpress; SHOW TABLES;"
```

Mesma lógica do volume acima, agora pro banco; o segundo comando loga no MariaDB como `root` (senha pedida interativamente, vem de `secrets/db_root_password.txt`) e roda três comandos SQL direto via `-e`: lista os bancos, troca pro banco `wordpress`, lista as tabelas — confirma que não está vazio. Implementado em `srcs/requirements/mariadb/tools/entrypoint.sh`.

### M · Persistence!

*"reboot the virtual machine... launch docker compose again... everything functional... changes... should still be here"*

```
sudo reboot
# depois de religar:
make ps
```

`sudo reboot` reinicia o sistema operacional da VM de verdade (não só os containers). Depois que ela volta, `make ps` confirma se os containers já estão de pé sozinhos — isso só acontece porque o serviço do Docker está habilitado pra iniciar no boot e `restart: unless-stopped` está em todo serviço no `docker-compose.yml`. Nenhum `make` precisa ser rodado manualmente.

### N · Configuration modification

*"the reviewer must ask... to modify the configuration of one service (e.g. changing the port)... rebuild and restart... must remain accessible"*

```
sed -i 's/NGINX_PORT=443/NGINX_PORT=8443/' srcs/.env
docker compose -f srcs/docker-compose.yml up -d nginx
```

`sed -i 's/.../.../'` edita o arquivo `.env` no lugar (`-i`), trocando o valor da porta; `docker compose up -d nginx` recria o container do nginx já lendo o novo valor (o `${NGINX_PORT:-443}` no `docker-compose.yml` é resolvido de novo). Espere \~15s (o WordPress religa o php-fpm) e teste a porta nova — ela precisa funcionar, e a antiga precisa parar de responder.

02

## Estrutura de arquivos

Onde cada coisa mora no repositório, e por que essa forma exata.

```
.
├── Makefile                      ← orquestra tudo, raiz do repo (exigência do subject)
├── secrets/                      ← senhas reais (NUNCA vão pro git)
│   └── *.txt.example             ← modelos versionados, sem senha de verdade
└── srcs/                         ← raiz exigida pelo subject p/ tudo de configuração
    ├── .env.example               ← modelo das variáveis não sensíveis
    ├── docker-compose.yml         ← a "planta" que liga os 3 containers
    └── requirements/
        ├── nginx/
        ├── wordpress/
        └── mariadb/
            ├── Dockerfile         ← receita da imagem (1 por serviço)
            ├── conf/              ← arquivos de configuração do serviço
            └── tools/entrypoint.sh← script que roda quando o container nasce
```

Essa separação não é estética: a régua de avaliação lê o `docker-compose.yml` procurando por coisas proibidas, confere que existe **um** `Dockerfile` por serviço, e espera encontrar exatamente `srcs/` e `Makefile` na raiz. Fugir dessa estrutura já reprova antes mesmo de olhar se o site funciona.

03

## Arquivo por arquivo

O que cada peça faz, por que ela existe dessa forma, e onde encontrá-la.

secrets/\*.txt + .gitignore

As quatro senhas do projeto (root do banco, senha do banco do WordPress, senha do admin do WordPress, senha do segundo usuário) ficam em arquivos de texto puro, **fora do git** — só os modelos `*.txt.example` são versionados.

Por quê: o subject exige Docker secrets pra credenciais, e a régua zera a nota na hora se achar qualquer senha real dentro do repositório Git. Docker monta esses arquivos como somente-leitura em `/run/secrets/<nome>` dentro de cada container — diferente de uma variável de ambiente, isso não aparece em `docker inspect` nem em logs.

usado por: docker-compose.yml, todos os entrypoint.sh

srcs/.env.example → srcs/.env

Guarda o que *não* é segredo: domínio (`vinda-si.42.fr`), porta do NGINX, nomes de usuário e de banco, título do site.

Por quê: o subject torna obrigatório o uso de um arquivo `.env`. Separar isso das senhas deixa claro, pra quem revisar o código, o que é configuração (pode ficar visível) e o que é credencial (nunca pode).

lido por: docker-compose.yml (env_file), todos os entrypoint.sh

srcs/docker-compose.yml

A planta que liga tudo: define os 3 serviços, a rede `inception` (bridge), os dois volumes com `driver_opts` apontando pro caminho certo no host, e qual secret cada container recebe.

#### Pontos que a régua confere linha por linha

— `networks:` precisa existir (aparece 4 vezes: uma por serviço + a definição no topo).\
— Nunca `network: host` nem `links:` — isolaria menos, ou usaria um mecanismo descontinuado do Docker.\
— `image: mariadb:inception` (idem nginx/wordpress) — o nome antes dos dois-pontos bate com o nome do serviço, e a tag explícita evita o `latest` implícito, que é proibido.\
— `restart: unless-stopped` em todos — containers precisam voltar sozinhos se caírem.\
— só o `nginx` publica porta pro host (`"${NGINX_PORT:-443}:443"`) — os outros dois só são alcançáveis de dentro da rede Docker.

aponta pra: requirements/\*/Dockerfile, secrets/\*.txt, srcs/.env

srcs/requirements/mariadb/

#### Dockerfile — base + instalação

`FROM debian:bookworm` (penúltima versão estável — a atual é a 13/trixie), instala só `mariadb-server`. Depois de instalar, apaga `/var/lib/mysql` e recria vazio — ver o bug #1 no capítulo seguinte, essa linha existe por causa dele.

#### conf/my.cnf — configuração do servidor

`bind-address = 0.0.0.0`: sem isso, o MariaDB só aceitaria conexões de dentro do próprio container, e o WordPress (em outro container) nunca conseguiria falar com ele pela rede Docker.

#### tools/entrypoint.sh — o script de inicialização

Na primeira vez que o container nasce (volume vazio), cria o banco `wordpress` e o usuário `wp_user` com a senha vinda do secret. Nas vezes seguintes, pula essa etapa (por isso é **idempotente**: pode reiniciar sem duplicar nem perder nada) e termina com `exec mariadbd` — o processo do banco vira o PID 1 do container, em primeiro plano, nunca em segundo plano.

ver também: bugs #1 e #2 no capítulo 06

srcs/requirements/wordpress/

#### Dockerfile

`debian:bookworm` + `php8.2-fpm` + as extensões PHP que o WordPress precisa + **wp-cli** (a ferramenta de linha de comando oficial do WordPress — é só um script, não uma imagem Docker pronta, então não fere a regra). Baixa o WordPress em build-time pra uma pasta "modelo" (`/usr/src/wordpress`), separada do volume de verdade.

#### conf/www.conf — pool do php-fpm

Configura o php-fpm pra escutar na porta TCP 9000 (em vez do socket Unix padrão), porque quem fala com ele é o NGINX, que mora em **outro container** — só alcançável pela rede, não pelo filesystem local.

#### tools/entrypoint.sh

Na primeira execução: copia os arquivos do WordPress pro volume real, gera o `wp-config.php`, roda `wp core install` (isso é o que **evita a tela de instalação** aparecer pro avaliador) e cria os dois usuários exigidos — o admin, com login sem "admin" no nome, e um segundo usuário comum. Espera o MariaDB responder antes de tudo isso, com um limite de 30 tentativas (nunca um loop infinito). Termina com `exec php-fpm8.2 -F`.

cria: usuário admin + usuário comum, exigidos pela régua

srcs/requirements/nginx/

#### Dockerfile

`debian:bookworm` + `nginx` + `openssl`. Gera um certificado TLS autoassinado **em build-time** (isso não é "senha", então não fere a regra de não ter senha no Dockerfile) com o domínio certo gravado como `CN`.

#### conf/nginx.conf.template

Só um bloco `server`, escutando `443 ssl`, com `ssl_protocols TLSv1.2 TLSv1.3;` — não existe nenhum bloco de porta 80 no arquivo, então o NGINX nem abre essa porta, não é um redirecionamento, é ausência total. Repassa tudo que termina em `.php` pro WordPress via `fastcgi_pass wordpress:9000` — o nome `wordpress` só resolve porque os dois estão na mesma rede Docker.

único container com porta publicada no host (443)

Makefile

Não builda nada sozinho — só chama `docker compose -f srcs/docker-compose.yml` com os parâmetros certos. Alvos principais: `up`/`all` (builda e sobe), `down`, `clean` (+ remove volumes/imagens), `fclean` (+ `sudo rm -rf` nos dados do host), `re` (fclean + all).

Por quê existe assim: a régua roda o Makefile direto, espera que ele configure tudo via docker compose sem erro. O `sudo` no `fclean` existe porque arquivos criados *dentro* dos containers (usuário `mysql`/`www-data`) não pertencem ao seu usuário no host.

README.md / USER_DOC.md / DEV_DOC.md

**README.md**: primeira linha em itálico com seu login, seções Description (com as 4 comparações pedidas: VM×Docker, Secrets×Env, Network×Host, Volumes×Bind mounts), Instructions, Resources (+ uso de IA).\
**USER_DOC.md**: pra quem só usa — subir/parar, achar senha, checar status.\
**DEV_DOC.md**: pra quem desenvolve — setup do zero, comandos do Makefile/compose, onde os dados persistem.

Por quê 3 arquivos: a régua tem uma seção só pra isso ("README check" e "Documentation check") e encerra a avaliação na hora se faltar qualquer um.

04

## Configuração antes do `make`

Dois arquivos não vêm no `git clone` de propósito — sem eles, o `make` falha. Só precisa fazer isso uma vez por checkout novo (clone recém-feito), não depois de cada `make fclean` — `fclean` apaga `/home/vinda-si/data/`, não os segredos nem o `.env`.

1\. secrets/\*.txt — as 4 senhas reais

```
cd secrets
for f in *.example; do cp "$f" "${f%.example}"; done
nano db_root_password.txt
nano db_password.txt
nano wp_admin_password.txt
nano wp_user_password.txt
cd ..
```

Em cada `nano`: apague o texto de exemplo, digite a senha, `Ctrl+O` Enter pra salvar, `Ctrl+X` pra sair.

Cada arquivo leva só a senha, sem linha extra. **Evite `'` (aspas simples) e `\` (barra invertida)** nas senhas — o script do MariaDB escapa a senha pra SQL (ver bug #1 no capítulo 05), mas esses são exatamente os dois caracteres que o escape precisa tratar, então uma senha "estranha" é um risco desnecessário no dia da defesa. Letras, números e símbolos como `!@#%*_-` são seguros.

2\. srcs/.env — configuração não sensível

```
cp srcs/.env.example srcs/.env
```

Confira que `DOMAIN_NAME=vinda-si.42.fr` e `NGINX_PORT=443` estão corretos — normalmente não precisa editar mais nada, o resto (usuários, título do site) já vem preenchido no modelo.

3\. /etc/hosts — resolver o domínio

Dentro da VM (sempre — é onde o NGINX escuta de verdade):

```
echo "127.0.0.1 vinda-si.42.fr" | sudo tee -a /etc/hosts
```

Pra testar também do navegador do **posto** (fora da VM) via o redirecionamento de porta do VirtualBox, seria preciso repetir o mesmo comando lá — mas contas de aluno no posto normalmente não têm `sudo`, então o caminho mais simples (o que usamos) é abrir o navegador *de dentro* da própria VM, onde esse `/etc/hosts` já resolve certo.

feito isso: cd \~/inception && make

05

## A jornada de montar a VM

O projeto *tem* que rodar dentro de uma máquina virtual — foi isso que fizemos, passo a passo, no posto da 42SP.

#### VirtualBox + disco em /sgoinfre

Criamos a VM via `VBoxManage` (linha de comando, não pela interface gráfica) com o disco salvo em `/sgoinfre/vinda-si/vms/` — essa pasta é compartilhada pela rede entre *todos* os postos da 42SP, diferente do `/goinfre` (local de uma única máquina) ou do `$HOME` (cota pequena demais pra um disco de VM). Isso permite religar a mesma VM em qualquer posto no dia da defesa.

#### Iniciar e desligar a VM com segurança

Comandos de bolso, usados o tempo todo ao longo do projeto — a VM fica em `/sgoinfre`, então funcionam de qualquer posto.

Iniciar (terminal do posto)

```
cd /sgoinfre/vinda-si/vms
VBoxManage startvm inception-vm --type gui
```

`--type gui` abre a janela gráfica da VM (precisa dela pra instalar o sistema ou usar o navegador de dentro da VM); use `--type headless` em vez disso se só for acessar por SSH, sem precisar ver a tela.

Desligar com segurança (de dentro da VM, via SSH ou janela gráfica)

```
sudo shutdown now
```

Desliga o sistema operacional da VM de forma limpa — fecha os containers graciosamente e desmonta o disco sem corromper nada. Fechar só a janela do VirtualBox (ou matar o processo) equivale a desligar a VM "no tapa", com risco de corromper o filesystem — por isso sempre usamos `shutdown` de dentro, nunca fechamos a janela direto.

Confirmar que desligou (terminal do posto)

```
VBoxManage list runningvms
```

Lista as VMs atualmente ligadas nesse posto — depois do `shutdown`, a `inception-vm` não deve mais aparecer (saída vazia).

#### Debian 13 na VM, Debian 12 nos containers

Instalamos Debian 13 (trixie, a estável atual) como sistema operacional *da VM em si* — isso é livre, o subject não exige nada aqui. O que precisa ser a penúltima estável é só a imagem base *dentro* dos Dockerfiles, e por isso ela é `debian:bookworm` (12).

#### Rede NAT + port-forward, não bridged

Um posto compartilhado de campus não garante que uma rede *bridged* funcione (política de DHCP/MAC da escola). Usamos NAT: a VM fica isolada atrás do posto, e abrimos duas regras de encaminhamento — porta 443 (site) e porta 2222 (SSH) do posto apontando pra VM.

#### Docker instalado, relógio corrigido

Instalamos o Docker Engine com o script oficial. Na primeira tentativa de `make`, o `apt-get update` falhou porque o relógio da VM estava com o fuso errado (ficou configurado como Reino Unido em vez de horário de Brasília) e atrasado — corrigido com `timedatectl` + `systemd-timesyncd`.

#### SSH entre posto e VM (sem clipboard)

A VM não tem o VirtualBox Guest Additions instalado (copiar/colar entre posto e VM não funciona, e decidimos não instalar — só conforto visual, sem efeito na nota). Resolvido acessando a VM via SSH a partir do terminal do posto, onde colar funciona normalmente.

Como montar essa conexão, passo a passo

**1. Pré-requisito**: o servidor SSH precisa estar instalado na VM — foi marcado como "SSH server" na tela de seleção de pacotes do instalador do Debian (capítulo 05, instalação). Se não tiver, dá pra instalar depois com `sudo apt install openssh-server` de dentro da VM.

**2. Criar a regra de encaminhamento de porta** (uma vez só, no terminal do *posto*, fora da VM):

```
# com a VM desligada:
VBoxManage modifyvm inception-vm --natpf1 "ssh,tcp,,2222,,22"

# ou, com a VM já ligada:
VBoxManage controlvm inception-vm natpf1 "ssh,tcp,,2222,,22"
```

Isso cria a regra `posto:2222 → VM:22` dentro da configuração de rede NAT da VM. `modifyvm` só funciona com a VM desligada; `controlvm ... natpf1` é a variante que funciona com ela ligada. Uma vez criada, a regra fica salva na configuração da VM — não precisa repetir isso toda vez que a VM reinicia.

**3. Conectar** (sempre que precisar, do terminal do posto):

```
ssh vinda-si@127.0.0.1 -p 2222
```

`127.0.0.1` (localhost) porque é o próprio posto que está escutando na porta 2222 e redirecionando pra VM — não é o IP da VM. `-p 2222` especifica a porta (SSH usa 22 por padrão, mas aqui o posto só libera 2222 pra isso). Ele pede a senha do usuário `vinda-si` dentro da VM (a que você definiu na instalação do Debian) — não tem nada a ver com chave SSH nem com o Vogsphere, é autenticação por senha simples.

**Não confundir com a chave SSH do Vogsphere** (próximo passo deste capítulo): essa aqui é uma conexão *posto → VM* pra facilitar o terminal; a chave SSH é uma conexão *de dentro da VM → Vogsphere*, pra autenticar o `git`. São duas coisas completamente separadas, usando o protocolo SSH para propósitos diferentes.

#### A chave SSH certa pro Vogsphere

O repositório que **vale a nota** não é o GitHub — é o **Vogsphere** (Gitea da 42). A VM não tinha chave SSH cadastrada no intra. Achamos a chave já registrada (RSA, de ago/2024) salva no `$HOME` do próprio posto, conferimos a fingerprint batendo com a do intra, e copiamos essa chave (via `scp` pelo túnel SSH já aberto) pra dentro da VM — sem gerar uma chave nova nem mexer no cadastro do intra.

#### O repositório final dentro da VM

Clonamos o Vogsphere vazio, e usamos `git archive HEAD | tar -x` a partir do checkout do GitHub (já validado) pra copiar só os arquivos rastreados — sem trazer histórico nem segredos reais — pra dentro do clone do Vogsphere. Depois, `git add`, `commit`, `push`.

06

## Os bugs reais que achamos (e corrigimos)

Problemas de verdade, encontrados testando na VM — não hipotéticos.

Bug #1 · segurança

#### Senha podia virar comando de shell

No script de inicialização do MariaDB, a senha era colocada direto dentro de um heredoc **sem aspas** no delimitador (`<<SQL`). Isso faz o bash expandir `$`, crase e barra invertida *antes* de mandar o texto pro banco — uma senha com uma crase dentro poderia executar um comando arbitrário como root dentro do container.

Correção

Trocamos pra um heredoc **protegido** (`<<'SQL'`, com aspas), que desliga toda expansão do shell, e passamos a substituir a senha como texto puro depois, já escapada para SQL por uma função `sql_escape()`.

srcs/requirements/mariadb/tools/entrypoint.sh

Bug #2 · dados nunca inicializavam

#### O MariaDB "esquecia" de criar o banco do WordPress

O pacote `mariadb-server` do Debian já inicializa um banco padrão *dentro da imagem*, no momento do `apt-get install`. Quando o Docker monta um volume novo (vazio) pela primeira vez sobre um caminho que já tinha conteúdo na imagem, ele **copia** esse conteúdo pro volume antes do nosso script rodar. Resultado: nosso entrypoint achava que o banco já estava pronto e pulava a criação do banco `wordpress` e do usuário `wp_user` — o WordPress nunca conseguia autenticar.

Correção

Adicionamos `rm -rf /var/lib/mysql` logo após instalar o pacote, garantindo que a imagem sempre parte de um diretório genuinamente vazio.

srcs/requirements/mariadb/Dockerfile

Bug #3 · modo bootstrap incompatível

#### `mariadbd --bootstrap` bloqueava a criação de usuário

Pra evitar deixar qualquer processo temporário rodando, a primeira versão corrigida usava `mariadbd --bootstrap` pra aplicar o SQL de configuração direto, sem subir um servidor completo. Só que, no MariaDB 10.11 (a versão do Debian 12), esse modo ativa implicitamente `--skip-grant-tables`, que **bloqueia** qualquer comando que mexa em permissões — `ALTER USER`, `CREATE USER`, `GRANT`. O comando falhava, o script abortava (por causa do `set -e`), o container reiniciava sozinho, e na segunda tentativa o diretório já existia — então pulava a inicialização de novo. Resultado idêntico ao bug #2, por um motivo diferente.

Correção

Voltamos ao padrão usado pelas imagens oficiais de MySQL/MariaDB: sobe um `mariadbd` temporário de verdade, só com socket local (`--skip-networking`, nunca alcançável pela rede), aplica o SQL via um cliente `mariadb` normal (que tem acesso completo às tabelas de permissão), desliga esse servidor temporário de forma limpa, e só então sobe o `mariadbd` definitivo como PID 1. Isso é um processo transitório e supervisionado — não é o hack de "processo em segundo plano" que o subject proíbe, que se refere ao *estado final* do container.

srcs/requirements/mariadb/tools/entrypoint.sh

07

## Os 10 testes da régua

Cada um rodado de verdade, duas vezes, na VM — uma no repositório do GitHub, outra do zero no do Vogsphere (o que vale a nota). Clique em "ver comando" pra abrir o detalhe de cada um.

01

#### Preliminary tests passou

"Any credentials... available in the git repository... evaluation stops and the mark is 0."

Garante que nenhuma senha real nunca foi commitada, nem está no histórico do git.

ver comando

```
git log --all -p | grep -iE "password|secret" | grep -v "\.example"
git ls-files | grep -E "secrets/.*\.txt$|srcs/\.env$"
```

Os dois voltam vazios (ou só referências de código) — nenhuma senha de verdade no repositório.

02

#### General instructions passou

sem `network: host`/`links:`/`--link`, sem hacks de loop infinito

ver comando

```
grep -n "network" srcs/docker-compose.yml
grep -rn "link" Makefile srcs/docker-compose.yml srcs/requirements/
grep -nE "tail -f|sleep infinity|while true" srcs/requirements/*/tools/entrypoint.sh
```

Rede presente, nenhum `--link` real (só um falso-positivo na palavra "permalinks"), nenhum hack de loop infinito.

03

#### Docker Basics passou

1 Dockerfile por serviço, não vazio, imagem própria, versão certa, nome = serviço

ver comando

```
ls -la srcs/requirements/*/Dockerfile
grep -H "^FROM" srcs/requirements/*/Dockerfile
docker images | grep inception
```

3 Dockerfiles não vazios, todos `FROM debian:bookworm`, imagens `mariadb`, `wordpress`, `nginx` nomeadas certo.

04

#### Docker Network passou

rede visível em `docker network ls`, explicação verbal

ver comando

```
docker network ls | grep inception
docker network inspect srcs_inception --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
```

Rede `srcs_inception` presente, os 3 containers conectados nela.

05

#### NGINX com SSL/TLS passou

porta 80 falha, TLS 1.2/1.3 funciona e é demonstrado, certificado correto

ver comando

```
curl -v http://vinda-si.42.fr
curl -v --tlsv1.2 --tls-max 1.2 https://vinda-si.42.fr -k
curl -v --tlsv1.1 --tls-max 1.1 https://vinda-si.42.fr -k
```

Porta 80: *connection refused*. TLS 1.2: conecta, certificado com `CN=vinda-si.42.fr`. TLS 1.1: forçado a falhar (*no protocols available*).

06

#### WordPress + php-fpm + volume passou

sem NGINX no container, volume no path certo, admin sem "admin" no login, comentário e edição refletidos

ver comando

```
grep -i nginx srcs/requirements/wordpress/Dockerfile
docker compose exec wordpress wp user list --allow-root
docker volume inspect srcs_wp_data | grep device
```

Sem NGINX, login admin `boss_vinda-si` (sem "admin"), segundo usuário `editor_vinda-si`, volume em `/home/vinda-si/data/wordpress`. No navegador: comentário como usuário comum, aprovação e edição de página como admin, tudo refletido no site.

07

#### MariaDB + volume passou

login no banco explicado, banco não vazio, volume no path certo

ver comando

```
docker compose exec mariadb mariadb -u root -p -e "SHOW DATABASES; USE wordpress; SHOW TABLES;"
```

Banco `wordpress` com 12 tabelas, usuários/posts/comentários reais — nada vazio.

08

#### Persistence! passou

reiniciar a VM, religar o compose, dados continuam

ver comando

```
sudo reboot
# depois de religar:
make ps
```

Containers voltam sozinhos (graças ao `restart: unless-stopped` + Docker habilitado no boot) — sem rodar `make` manualmente. Posts, comentários e páginas editadas continuam lá.

09

#### Modificação de configuração passou

trocar a porta de um serviço ao vivo, rebuildar, continuar funcionando

ver comando

```
sed -i 's/NGINX_PORT=443/NGINX_PORT=8443/' srcs/.env
docker compose up -d nginx
```

Site respondeu na porta nova, a antiga passou a falhar. (Detectamos um 502 passageiro no primeiro teste — era só o WordPress ainda terminando de religar; esperar \~15s resolve.)

10

#### README + Documentation check passou

primeira linha exata, seções obrigatórias, USER_DOC/DEV_DOC presentes

ver comando

```
head -1 README.md
grep -E "^## " README.md
wc -l USER_DOC.md DEV_DOC.md
```

Primeira linha certa, seções Description/Instructions/Resources presentes, os dois docs com conteúdo real.

08

## Perguntas da régua e da defesa

A seção "Activity overview" da régua exige que você explique estes pontos em termos simples — e o avaliador pode ir além deles. Respostas-modelo pra decorar a ideia, não o texto exato.

Como o Docker e o docker compose funcionam?

Uma imagem Docker empacota uma aplicação com tudo que ela precisa pra rodar — bibliotecas, binários, configuração — num artefato somente-leitura. Rodar essa imagem cria um **container**: um processo isolado que compartilha o kernel do sistema operacional do host, mas enxerga seu próprio filesystem, rede e espaço de processos. O `docker compose` lê um arquivo YAML declarativo (`docker-compose.yml`) e orquestra **vários** containers relacionados de uma vez só — builda as imagens, cria a rede e os volumes, sobe tudo na ordem certa — em vez de eu digitar `docker build`/`docker run` manualmente pra cada um.

Diferença entre uma imagem Docker usada com e sem docker compose?

A imagem é exatamente a mesma — o mesmo artefato, buildado do mesmo `Dockerfile`. O que muda é **como** ela é executada. Sem compose, eu precisaria repetir manualmente, toda vez, todas as flags: `--network inception`, `-v wp_data:/var/www/html`, `--env-file .env`, `--restart unless-stopped`. Com compose, isso fica declarado uma vez só no `docker-compose.yml`, versionado no git, e reproduzido de forma idêntica com um único `docker compose up`.

O benefício do Docker comparado a VMs?

Um container compartilha o kernel do sistema operacional do host e só isola processos, filesystem e rede (via namespaces e cgroups do Linux) — por isso é muito mais leve, sobe em segundos e usa bem menos RAM/disco que uma VM. Uma VM virtualiza o hardware inteiro e roda um kernel próprio pra cada instância — isolamento mais forte, mas muito mais pesado. Pra uma stack onde cada serviço só precisa de isolamento de aplicação (não de um kernel diferente), containers são a escolha mais eficiente — por isso o próprio Inception roda dentro de *uma única VM*, com três containers dentro dela, em vez de três VMs separadas.

Pertinência da estrutura de diretórios do projeto?

Ela separa claramente quatro responsabilidades: `secrets/` guarda credenciais (nunca vai pro git), `srcs/.env` guarda configuração não sensível, `srcs/docker-compose.yml` define a infraestrutura (como os serviços se conectam), e cada `srcs/requirements/<serviço>/` isola a implementação de um serviço (seu `Dockerfile`, configuração e script de inicialização). Isso deixa fácil localizar e revisar qualquer peça isoladamente, e permite que o `.gitignore` exclua só o que realmente precisa ficar de fora (os segredos), sem tocar no resto.

Explique docker-network em termos simples.

É uma sub-rede virtual isolada que o Docker cria só pros containers do projeto. Dentro dela, cada container enxerga os outros pelo **nome do serviço** como se fosse um hostname — é assim que o `nginx` encontra o `wordpress` na porta 9000, e o `wordpress` encontra o `mariadb`, sem precisar saber IP de ninguém. Diferente de `network: host`, que jogaria o container direto na rede do host sem isolamento nenhum de portas.

Como logar no banco de dados?

`docker compose -f srcs/docker-compose.yml exec mariadb mariadb -u root -p`, e digitar a senha que está em `secrets/db_root_password.txt`. De dentro do banco: `SHOW DATABASES;` mostra o banco `wordpress`, `USE wordpress; SHOW TABLES;` mostra as 12 tabelas do WordPress (`wp_users`, `wp_posts` etc.).

### Outras perguntas prováveis

Não estão escritas literalmente na régua, mas são o tipo de pergunta natural em cima de cada decisão técnica do projeto.

| Pergunta provável | Resposta curta |
| --- | --- |
| Por que secrets em vez de variável de ambiente pra senha? | Env var aparece em `docker inspect` e em `/proc/pid/environ`; secrets ficam só em `/run/secrets/`, somente leitura, invisíveis fora do container. |
| O que acontece se um container cair? | `restart: unless-stopped` no compose — o Docker sobe ele de novo sozinho, a menos que alguém tenha parado manualmente. |
| Por que Debian e não Alpine? | Escolha livre do subject; Debian tem `apt` e documentação mais familiares, o que facilitou escrever e depurar os três Dockerfiles. |
| Por que usar o wp-cli em vez de instalar pelo navegador? | Automatiza 100% a instalação (sem clique nenhum), evita a tela de instalação aparecer pro avaliador, e deixa o processo reproduzível — essencial porque o container precisa subir sozinho via `make`. |
| O que é PID 1 e por que importa? | É o primeiro processo do container, quem recebe os sinais que o Docker manda (ex. `SIGTERM` ao parar). Se PID 1 fosse um hack tipo `tail -f`, o Docker não conseguiria desligar o serviço de verdade com elegância — por isso todo entrypoint termina com `exec`, que substitui o processo do script pelo processo real do serviço. |
| Por que NGINX fala com o WordPress por FastCGI e não HTTP? | php-fpm não é um servidor HTTP, é um processo FastCGI — é o protocolo nativo entre NGINX e PHP, mais simples e direto que colocar outro servidor HTTP no meio. |
| Por que dois volumes separados (banco e site) em vez de um só? | Ciclos de vida e conteúdos completamente diferentes (binário/tabelas do banco vs. arquivos PHP e uploads) — mais fácil de limpar, inspecionar ou fazer backup de um sem mexer no outro. |
| Como garantir que reiniciar não duplica nem perde dados? | Os `entrypoint.sh` checam, a cada boot, se o volume já foi inicializado (banco criado, WordPress instalado) antes de repetir qualquer passo de setup — por isso são chamados de *idempotentes*. |
| O certificado TLS é confiável? | Não, é autoassinado — e o subject permite isso explicitamente ("doesn't have to be recognized... a warning may appear"). O que importa é usar TLS 1.2/1.3 de verdade, demonstrado com `curl --tlsv1.2`. |

09

## Checklist final

Onde as coisas estão agora.

- ✓ Repositório do Vogsphere validado do zero — clone vazio, segredos recriados, limpeza completa do avaliador, `make`, os 10 testes.
- ✓ VM configurada e acessível de qualquer posto (disco em `/sgoinfre`, chave SSH correta).
- ✓ Ambiente zerado (sem containers/imagens/volumes/dados residuais) — pronto pra `make` no dia da defesa.

Guia de estudo pessoal — Inception, 42SP, login vinda-si.