*Documentação de desenvolvimento — Inception*

# DEV_DOC.md

Guia para quem vai desenvolver, manter ou revisar este projeto.

## Pré-requisitos

- Uma VM Linux (o projeto foi desenhado para rodar em uma VM, conforme o
  subject).
- Docker Engine + plugin `docker compose` (Compose v2) instalados.
- Porta 443 livre na VM.

## Configuração do ambiente (do zero)

1. Clonar o repositório.
2. Criar os arquivos de segredo a partir dos exemplos:

   ```sh
   cd secrets
   for f in *.example; do cp "$f" "${f%.example}"; done
   # edite cada *.txt e coloque senhas fortes de verdade
   cd ..
   ```

3. Criar o `.env` a partir do exemplo:

   ```sh
   cp srcs/.env.example srcs/.env
   # ajuste DOMAIN_NAME, NGINX_PORT, nomes de usuário/banco se necessário
   ```

4. Apontar o domínio para a própria VM (necessário para acessar
   `https://vinda-si.42.fr`):

   ```sh
   echo "127.0.0.1 vinda-si.42.fr" | sudo tee -a /etc/hosts
   ```

Nenhuma senha deve nunca ir para `srcs/.env`, para os `Dockerfile`s ou
para o `docker-compose.yml` — apenas para `secrets/*.txt`.

## Build e execução via Makefile / Docker Compose

O `Makefile`, na raiz, é só um wrapper conveniente em torno de
`docker compose -f srcs/docker-compose.yml`:

```sh
make            # == docker compose -f srcs/docker-compose.yml up --build -d
                #    (após criar /home/vinda-si/data/{wordpress,mariadb})
make ps         # docker compose ... ps
make logs       # docker compose ... logs -f
make stop       # docker compose ... stop
make start      # docker compose ... start
make restart    # docker compose ... restart
make down       # docker compose ... down          (mantém volumes)
make clean      # down + remove volumes e imagens locais do projeto
make fclean     # clean + apaga /home/vinda-si/data (perde os dados!)
make re         # fclean + make (rebuild total do zero)
```

Comandos equivalentes direto no Compose, se preferir não usar o Makefile:

```sh
docker compose -f srcs/docker-compose.yml build              # só builda as imagens
docker compose -f srcs/docker-compose.yml up -d               # sobe em background
docker compose -f srcs/docker-compose.yml ps                  # nomes/estado dos containers
docker compose -f srcs/docker-compose.yml exec wordpress bash # shell dentro de um container
docker network ls                                              # ver a rede "srcs_inception"
docker volume ls                                                # ver os volumes srcs_wp_db / srcs_wp_data
docker volume inspect srcs_wp_data                              # confirmar o path /home/vinda-si/data/...
```

## Arquitetura dos serviços

- `srcs/docker-compose.yml` define os 3 serviços (`nginx`, `wordpress`,
  `mariadb`), a rede `inception` (bridge) e os volumes `wp_data`/`wp_db`
  (bind para `/home/vinda-si/data/wordpress` e `/home/vinda-si/data/mariadb`).
- `srcs/requirements/<serviço>/Dockerfile` — cada um `FROM debian:bookworm`,
  instala só o software daquele serviço e termina com um processo em
  foreground (nunca com `tail -f`, `sleep infinity` ou similares).
- `srcs/requirements/<serviço>/tools/entrypoint.sh` (wordpress e mariadb) —
  faz a configuração inicial (criar banco/usuários, instalar o WordPress
  via `wp-cli`) **apenas na primeira execução**, checando se o volume já
  contém dados, e depois faz `exec` do processo principal (`mariadbd`,
  `php-fpm8.2 -F`), que passa a ser o PID 1 do container.
- NGINX fala com o WordPress via FastCGI na porta 9000 (`fastcgi_pass
  wordpress:9000`, resolvido pela rede Docker) e serve os arquivos
  estáticos lendo o mesmo volume `wp_data` montado como somente leitura.

## Onde os dados ficam e como persistem

- Banco de dados do WordPress: volume `wp_db`, mapeado para
  `/home/vinda-si/data/mariadb` no host (dados internos do MariaDB).
- Arquivos do WordPress (core, plugins, temas, uploads): volume
  `wp_data`, mapeado para `/home/vinda-si/data/wordpress` no host.

Como são volumes Docker (não dados dentro do container), eles sobrevivem
a `docker compose down`, a rebuilds de imagem (`make re` sem `fclean`) e
a reboots da VM — desde que os arquivos em `/home/vinda-si/data/` não
sejam apagados manualmente. Só `make fclean` remove esses dados de fato.
