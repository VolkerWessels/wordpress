# About this wordpress image
Docker container for Hosting WordPress on Azure App Service using [Caddy server](https://caddyserver.com/docs/)
Caddy is a powerful, extensible platform to serve your sites, services, and apps, written in Go. 
If you're new to Caddy, the way you serve the Web is about to change.

# How to use this image

```console
$ docker run --name some-wordpress --network some-network -d ghcr.io/volkerwessels/wordpress
```

The following environment variables are also honored for configuring your WordPress instance (by [a custom `wp-config.php` implementation](https://github.com/docker-library/wordpress/blob/master/wp-config-docker.php)):

-	`-e WORDPRESS_DB_HOST=...`
-	`-e WORDPRESS_DB_USER=...`
-	`-e WORDPRESS_DB_PASSWORD=...`
-	`-e WORDPRESS_DB_NAME=...`
-	`-e WORDPRESS_TABLE_PREFIX=...`
-	`-e WORDPRESS_AUTH_KEY=...`, `-e WORDPRESS_SECURE_AUTH_KEY=...`, `-e WORDPRESS_LOGGED_IN_KEY=...`, `-e WORDPRESS_NONCE_KEY=...`, `-e WORDPRESS_AUTH_SALT=...`, `-e WORDPRESS_SECURE_AUTH_SALT=...`, `-e WORDPRESS_LOGGED_IN_SALT=...`, `-e WORDPRESS_NONCE_SALT=...` (default to unique random SHA1s, but only if other environment variable configuration is provided)
-	`-e WORDPRESS_DEBUG=1` (defaults to disabled, non-empty value will enable `WP_DEBUG` in `wp-config.php`)
-	`-e WORDPRESS_CONFIG_EXTRA=...` (defaults to nothing, non-empty value will be embedded verbatim inside `wp-config.php` -- especially useful for applying extra configuration values this image does not provide by default such as `WP_ALLOW_MULTISITE`; see [docker-library/wordpress#142](https://github.com/docker-library/wordpress/pull/142) for more details)

The `WORDPRESS_DB_NAME` needs to already exist on the given MySQL server; it will not be created by the `wordpress` container.

If you'd like to be able to access the instance from the host without the container's IP, standard port mappings can be used:

```console
$ docker run --name some-wordpress -p 8080:80 -d wordpress
```

Then, access it via `http://localhost:8080` or `http://host-ip:8080` in a browser.

When running WordPress with TLS behind a reverse proxy such as NGINX which is responsible for doing TLS termination, be sure to set `X-Forwarded-Proto` appropriately (see ["Using a Reverse Proxy" in "Administration Over SSL" in upstream's documentation](https://wordpress.org/support/article/administration-over-ssl/#using-a-reverse-proxy)). No additional environment variables or configuration should be necessary (this image automatically adds the noted `HTTP_X_FORWARDED_PROTO` code to `wp-config.php` if *any* of the above-noted environment variables are specified).

If your database requires SSL, [WordPress ticket #28625](https://core.trac.wordpress.org/ticket/28625) has the relevant details regarding support for that with WordPress upstream. As a workaround, [the "Secure DB Connection" plugin](https://wordpress.org/plugins/secure-db-connection/) can be extracted into the WordPress directory and the appropriate values described in the configuration of that plugin added in `wp-config.php`.

## Docker Secrets

As an alternative to passing sensitive information via environment variables, `_FILE` may be appended to the previously listed environment variables, causing the initialization script to load the values for those variables from files present in the container. In particular, this can be used to load passwords from Docker secrets stored in `/run/secrets/<secret_name>` files. For example:

```console
$ docker run --name some-wordpress -e WORDPRESS_DB_PASSWORD_FILE=/run/secrets/mysql-root ... -d wordpress:tag
```

Currently, this is supported for `WORDPRESS_DB_HOST`, `WORDPRESS_DB_USER`, `WORDPRESS_DB_PASSWORD`, `WORDPRESS_DB_NAME`, `WORDPRESS_AUTH_KEY`, `WORDPRESS_SECURE_AUTH_KEY`, `WORDPRESS_LOGGED_IN_KEY`, `WORDPRESS_NONCE_KEY`, `WORDPRESS_AUTH_SALT`, `WORDPRESS_SECURE_AUTH_SALT`, `WORDPRESS_LOGGED_IN_SALT`, `WORDPRESS_NONCE_SALT`, `WORDPRESS_TABLE_PREFIX`, and `WORDPRESS_DEBUG`.

## ... via [`docker stack deploy`](https://docs.docker.com/engine/reference/commandline/stack_deploy/) or [`docker-compose`](https://github.com/docker/compose)

Example `docker-compose.yml` for `wordpress`:

```yaml
version: "3.8"

services:
  db:
    image: mariadb:latest
    networks:
      - backend
    volumes:
      - dbdata:/var/lib/mysql
    restart: always
    expose:
      - 3306
    env_file:
      - "mariadb.env"
    healthcheck:
      test: pidof mariadb || exit 1
      interval: 120s
      timeout: 10s
      retries: 3
      start_period: 40s
  wordpress:
    image: ghcr.io/volkerwessels/wordpress:latest
    restart: always
    networks:
      - backend
    ports:
      - "80:80"
      - "443:443"
      - "2019:2019"
    env_file:
      - "wordpress.env"
    volumes:
      - wordpress:/home/site/wwwroot
      - type: bind
        source: ./docker/etc/caddy
        target: /etc/caddy
    command: ["caddy", "run", "--config", "/etc/caddy/Caddyfile.dev", "--adapter", "caddyfile"]

networks:
  backend:

volumes:
  dbdata:
  wordpress:
```
