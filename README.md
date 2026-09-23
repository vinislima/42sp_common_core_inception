*This project has been created as part of the 42 curriculum by vinislima*

# Inception

## Description

Inception é um projeto de administração de sistemas do currículo da 42 cujo
objetivo é montar, do zero, uma pequena infraestrutura web usando **Docker**
e **Docker Compose**, com cada serviço isolado no seu próprio container.

A stack é composta por três serviços:

- **NGINX** — único ponto de entrada da infraestrutura, servindo HTTPS
  (TLSv1.2/TLSv1.3) na porta 443 e repassando as requisições PHP ao
  WordPress via FastCGI.
- **WordPress + php-fpm** — CMS instalado e configurado automaticamente
  (sem passar pela tela de instalação), servido pelo php-fpm.
- **MariaDB** — banco de dados relacional usado pelo WordPress.

Os três containers se comunicam por uma rede Docker dedicada
(`inception`), e dois volumes Docker persistem, respectivamente, os
arquivos do WordPress e os dados do MariaDB em `/home/vinislima/data/`
no host.

### Estrutura do projeto

```text
.
├── Makefile
├── secrets/                  # senhas usadas como Docker secrets (não versionadas)
└── srcs/
    ├── .env                  # variáveis de configuração não sensíveis (não versionado)
    └── requirements/
        ├── nginx/
        ├── wordpress/
        └── mariadb/
```

Cada pasta em `requirements/` contém seu próprio `Dockerfile` (escrito do
zero, a partir de `debian:bookworm`), arquivos de configuração (`conf/`) e,
quando necessário, um script de entrypoint (`tools/entrypoint.sh`) que
inicializa o serviço e termina rodando o processo principal em
foreground (PID 1), sem daemonizar e sem loops infinitos.

### Principais escolhas de design

- **Imagem base:** Debian 12 (bookworm), a penúltima versão estável do
  Debian, escolhida por ter documentação e pacotes (`apt`) bem
  conhecidos, o que simplifica escrever e depurar os Dockerfiles.
- **Um serviço por container:** cada Dockerfile instala e roda apenas o
  software do seu serviço (ex.: o container do WordPress não tem NGINX).
- **Inicialização idempotente:** os `entrypoint.sh` verificam se o volume
  já foi inicializado (banco criado, WordPress instalado) antes de repetir
  o setup, para que os containers possam reiniciar sem perder nem
  duplicar dados.
- **Segredos fora do código:** nenhuma senha aparece em Dockerfile,
  `docker-compose.yml` ou no código-fonte; tudo vem de `secrets/*.txt`
  (Docker secrets) ou de `srcs/.env` (configuração não sensível).

### Comparações pedidas pelo subject

**Virtual Machines vs Docker**
Uma VM virtualiza hardware completo e roda um kernel próprio para cada
instância, o que é mais pesado (RAM/CPU/boot) mas garante isolamento
total. Um container Docker compartilha o kernel do host e virtualiza
apenas o espaço de usuário (processos, filesystem, rede), o que o torna
muito mais leve e rápido de iniciar, ao custo de um isolamento um pouco
menor que uma VM completa.

**Secrets vs Environment Variables**
Variáveis de ambiente (`.env`) são adequadas para configuração não
sensível (nome de domínio, nomes de banco/usuário), mas ficam visíveis em
`docker inspect`, em `/proc/<pid>/environ` e em logs. Docker secrets são
montados como arquivos somente leitura em `/run/secrets/` dentro do
container, não aparecem em `docker inspect` nem em variáveis de ambiente
do processo, por isso são usados aqui para todas as senhas.

**Docker Network vs Host Network**
Com `network: host` o container usa a pilha de rede do próprio host,
sem isolamento de portas — qualquer serviço no container fica exposto
como se rodasse diretamente na máquina. Uma rede Docker dedicada (usada
neste projeto) isola os containers em sua própria sub-rede virtual, com
resolução de nome pelo nome do serviço (ex.: `mariadb`, `wordpress`), e só
expõe ao host as portas explicitamente mapeadas (aqui, apenas a 443 do
NGINX).

**Docker Volumes vs Bind Mounts**
Um bind mount aponta diretamente para um caminho do host, gerenciado
manualmente por quem administra a máquina. Um volume Docker (usado neste
projeto, com `driver_opts` apontando para `/home/vinislima/data/...`) é
gerenciado pelo próprio Docker (criação, ciclo de vida, permissões),
sobrevive à remoção dos containers e é a forma recomendada de persistir
dados como o banco do WordPress e os arquivos do site.

## Instructions

Pré-requisitos: Docker e Docker Compose instalados em uma VM Linux.

```sh
git clone <repo> && cd 42sp_common_core_inception
cp secrets/*.txt.example secrets/   # renomeie removendo .example e edite as senhas
cp srcs/.env.example srcs/.env      # ajuste o domínio/usuários se necessário
echo "127.0.0.1 vinislima.42.fr" | sudo tee -a /etc/hosts
make                                 # builda as imagens e sobe os 3 containers
```

Acesse `https://vinislima.42.fr` no navegador (aceite o aviso de
certificado autoassinado). Veja `USER_DOC.md` para detalhes de uso e
`DEV_DOC.md` para detalhes de desenvolvimento/manutenção.

## Resources

- [Documentação oficial do Docker](https://docs.docker.com/)
- [Documentação do Docker Compose](https://docs.docker.com/compose/)
- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)
- [Documentação do NGINX](https://nginx.org/en/docs/)
- [Documentação do MariaDB](https://mariadb.com/kb/en/documentation/)
- Documentação oficial do Debian (`man`, `apt`, pacotes `mariadb-server`,
  `php-fpm`, `nginx`)

**Uso de IA:** a assistente Claude (Anthropic) foi utilizada exclusivamente no planejamento do projeto e na elaboração desta documentação, auxiliando na organização dos requisitos e na descrição das etapas de implementação.
