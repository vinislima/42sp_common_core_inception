*Documentação de usuário — Inception*

# USER_DOC.md

Este documento explica, em termos simples, como usar a stack Inception
sem precisar entender os detalhes internos de cada container.

## Quais serviços a stack oferece

| Serviço | O que faz |
| --- | --- |
| NGINX | Ponto de entrada HTTPS do site (porta 443) |
| WordPress | O site/CMS em si, incluindo o painel de administração |
| MariaDB | Banco de dados que guarda o conteúdo do WordPress |

## Iniciar e parar o projeto

Sempre a partir da raiz do repositório:

```sh
make            # builda as imagens (se necessário) e inicia os 3 containers
make ps         # mostra o status de cada container
make stop       # para os containers sem apagar nada
make start      # retoma os containers parados
make down       # para e remove os containers (os dados nos volumes permanecem)
```

## Acessar o site e o painel de administração

1. Garanta que `vinda-si.42.fr` resolve para o IP da VM. Em geral isso é
   feito adicionando ao `/etc/hosts` (na própria VM ou na máquina que vai
   acessar o navegador):

   ```text
   <IP-da-VM> vinda-si.42.fr
   ```

2. Acesse `https://vinda-si.42.fr` no navegador.
   - Por ser um certificado autoassinado, o navegador vai mostrar um
     aviso de segurança — isso é esperado, basta continuar/aceitar.
   - `http://` (porta 80) não funciona por design: o único ponto de
     entrada é a porta 443 em HTTPS.
3. Painel de administração: `https://vinda-si.42.fr/wp-admin`
   - Usuário administrador: valor de `WP_ADMIN_USER` (ver `srcs/.env`).
   - Existe também um segundo usuário (não administrador), definido em
     `WP_USER`, para publicar/comentar sem privilégios de admin.

## Localizar e gerenciar credenciais

- Senhas ficam em `secrets/*.txt`, na raiz do repositório (arquivos
  ignorados pelo git — nunca são enviados ao GitHub).
  - `db_root_password.txt` — senha do usuário `root` do MariaDB.
  - `db_password.txt` — senha do usuário de banco do WordPress.
  - `wp_admin_password.txt` — senha do usuário administrador do WordPress.
  - `wp_user_password.txt` — senha do segundo usuário do WordPress.
- Nomes de usuário e domínio (não sensíveis) ficam em `srcs/.env`.
- Para trocar uma senha: edite o arquivo correspondente em `secrets/` e
  rode `make re` (recria os containers). Como o WordPress e o banco já
  existem no volume, a senha do sistema (Docker secret) só terá efeito
  em uma reinstalação; para trocar a senha de um usuário já criado, use
  o próprio painel do WordPress (Usuários → Editar) ou peça ajuda ao
  desenvolvedor (ver `DEV_DOC.md`).

## Verificar se os serviços estão funcionando

```sh
make ps                              # os 3 containers devem aparecer como "running"/"Up"
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

- Se `https://vinda-si.42.fr` carregar o site (e não a tela de instalação
  do WordPress), o WordPress e o banco estão corretamente configurados.
- Se aparecer erro de conexão, confira `make ps` e os logs acima para
  identificar qual dos três containers não subiu.
