# secrets/

> Documentação interna — não faz parte da documentação obrigatória do projeto.

Estes arquivos guardam senhas em texto puro que o Docker expõe aos
containers via **Docker secrets** (montados em `/run/secrets/<nome>`).
Eles não são versionados (veja `.gitignore` na raiz do repositório).

## Arquivos

| Arquivo | Usado por | Conteúdo |
| --- | --- | --- |
| `db_root_password.txt` | mariadb | senha do usuário `root` do MariaDB |
| `db_password.txt` | mariadb, wordpress | senha do usuário de banco do WordPress |
| `wp_admin_password.txt` | wordpress | senha do usuário administrador do WordPress |
| `wp_user_password.txt` | wordpress | senha do segundo usuário (não administrador) do WordPress |

Cada arquivo deve conter apenas a senha, sem quebras de linha extras.

## Como criar os arquivos reais

```sh
cd secrets
for f in *.example; do cp "$f" "${f%.example}"; done
# edite cada *.txt e coloque senhas fortes de verdade
```
