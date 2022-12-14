#!/usr/bin/env bash
set -Eeuo pipefail
curr_dir="$(dirname $0)"
source "$curr_dir/set-timezone.sh"

set_timezone

if [[ "$1" == caddy* ]] || [ "$1" = 'php-fpm' ]; then
	uid="$(id -u)"
	gid="$(id -g)"
	if [ "$uid" = '0' ]; then
		case "$1" in
			caddy*)
				user="${CADDY_RUN_USER:-caddy}"
				group="${CADDY_RUN_GROUP:-caddy}"
				;;
			*) # php-fpm
				user='caddy'
				group='caddy'
				;;
		esac
	else
		user="$uid"
		group="$gid"
	fi

	if [ ! -e index.php ] && [ ! -e wp-includes/version.php ]; then
		# if the directory exists and WordPress doesn't appear to be installed AND the permissions of it are root:root, let's chown it (likely a Docker-created directory)
		if [ "$uid" = '0' ] && [ "$(stat -c '%u:%g' .)" = '0:0' ]; then
			chown "$user:$group" .
		fi

		echo >&2 "WordPress not found in $PWD - copying now..."
		if [ -n "$(find -mindepth 1 -maxdepth 1 -not -name wp-content)" ]; then
			echo >&2 "WARNING: $PWD is not empty! (copying anyhow)"
		fi
		sourceTarArgs=(
			--create
			--file -
			--directory /usr/src/wordpress
			--owner "$user" --group "$group"
		)
		targetTarArgs=(
			--extract
			--file -
		)
		if [ "$uid" != '0' ]; then
			# avoid "tar: .: Cannot utime: Operation not permitted" and "tar: .: Cannot change mode to rwxr-xr-x: Operation not permitted"
			targetTarArgs+=( --no-overwrite-dir )
		fi
		# loop over "pluggable" content in the source, and if it already exists in the destination, skip it
		# https://github.com/docker-library/wordpress/issues/506 ("wp-content" persisted, "akismet" updated, WordPress container restarted/recreated, "akismet" downgraded)
		for contentPath in \
			/usr/src/wordpress/.htaccess \
			/usr/src/wordpress/wp-content/*/*/ \
		; do
			contentPath="${contentPath%/}"
			[ -e "$contentPath" ] || continue
			contentPath="${contentPath#/usr/src/wordpress/}" # "wp-content/plugins/akismet", etc.
			if [ -e "$PWD/$contentPath" ]; then
				echo >&2 "WARNING: '$PWD/$contentPath' exists! (not copying the WordPress version)"
				sourceTarArgs+=( --exclude "./$contentPath" )
			fi
		done
		tar "${sourceTarArgs[@]}" . | tar "${targetTarArgs[@]}"
		echo >&2 "Complete! WordPress has been successfully copied to $PWD"
	fi

	wpEnvs=( "${!WORDPRESS_@}" )
	if [ ! -s wp-config.php ] && [ "${#wpEnvs[@]}" -gt 0 ]; then
		for wpConfigDocker in \
			wp-config-docker.php \
			/usr/src/wordpress/wp-config-docker.php \
		; do
			if [ -s "$wpConfigDocker" ]; then
				echo >&2 "No 'wp-config.php' found in $PWD, but 'WORDPRESS_...' variables supplied; copying '$wpConfigDocker' (${wpEnvs[*]})"
				# using "awk" to replace all instances of "put your unique phrase here" with a properly unique string (for AUTH_KEY and friends to have safe defaults if they aren't specified with environment variables)
				awk '
					/put your unique phrase here/ {
						cmd = "head -c1m /dev/urandom | sha1sum | cut -d\\  -f1"
						cmd | getline str
						close(cmd)
						gsub("put your unique phrase here", str)
					}
					{ print }
				' "$wpConfigDocker" > wp-config.php
				if [ "$uid" = '0' ]; then
					# attempt to ensure that wp-config.php is owned by the run user
					# could be on a filesystem that doesn't allow chown (like some NFS setups)
					chown "$user:$group" wp-config.php || true
				fi
				break
			fi
		done
	fi
fi

if [ ! -e /home/Caddyfile ]; then
  echo >&2 "Caddyfile not found in /home - copying now..."
  install /etc/caddy/Caddyfile --owner="${CADDY_RUN_USER:-caddy}" --group="${CADDY_RUN_GROUP:-caddy}" --target-directory=/home/
fi

_ENABLE_SSH="${ENABLE_SSH:-false}"
if [ "$_ENABLE_SSH" = true ] || [ "${WORDPRESS_DEBUG:-false}" = true ]; then
  source "$curr_dir/ssh-setup.sh"
  ssh_setup
fi

printf '%b' '\nWiting /usr/local/etc/php-fpm.d/zz-php-fpm-pool.conf... \t\n'

cat >/usr/local/etc/php-fpm.d/zz-php-fpm-pool.conf <<EOL
[www]
pm = ${PHP_FPM_PM:-dynamic}
pm.max_children = ${PHP_FPM_PM_MAX_CHILDREN:-25}
pm.start_servers = ${PHP_FPM_PM_MAX_CHILDREN:-10}
pm.min_spare_servers = ${PHP_FPM_PM_MIN_SPARE_SERVERS:-5}
pm.max_spare_servers = ${PHP_FPM_PM_MAX_SPARE_SERVERS:-20}
pm.process_idle_timeout = ${PHP_FPM_PM_PROCESS_IDLE_TIMEOUT:-10s}
pm.max_requests = ${PHP_FPM_PM_MAX_REQUESTS:-0}

EOL

printf '%b' '\nStarting PHP-FPM & Caddy...\t\n'

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
else
  php-fpm -F &
fi

exec "$@"