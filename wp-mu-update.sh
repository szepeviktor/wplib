#!/bin/bash
#
# Update MU plugins.

WP_CLI="wp --allow-root"
MU_BCK_PATH="${HOME}/.wp-cli/backup/muplugin"

Parse_ghu_uri() {
    sed -n '0,/^\s*GitHub Plugin URI:/{s/GitHub Plugin URI:\s*\(\S*\)/\1/p}'
}

if ! ${WP_CLI} core is-installed; then
    echo "WordPress not found here ($(pwd))" >&2
    exit 99
fi

mkdir -p "$MU_BCK_PATH" &> /dev/null

WP_CONTENT_DIR="$(${WP_CLI} eval 'echo WP_CONTENT_DIR;')"

${WP_CLI} plugin list --status=must-use --field=name \
    | while read MU_PLUGIN; do
        MU_PLUGIN_PATH="${WP_CONTENT_DIR}/mu-plugins/${MU_PLUGIN}.php"
        [ -s "$MU_PLUGIN_PATH" ] || continue

        GHU_URL="$(Parse_ghu_uri < "$MU_PLUGIN_PATH")"
        [ "${GHU_URL#http}" == "$GHU_URL" ] && continue
        MU_PLUGIN_URL="${GHU_URL/\/tree\/master\///raw/master/}/${MU_PLUGIN}.php"

        NEW_GHU_URL="$(wget -q -O- "$MU_PLUGIN_URL" | Parse_ghu_uri)"
        if [ "$NEW_GHU_URL" == "$GHU_URL" ]; then
            # Backup MU plugin
            if mv -v -f "$MU_PLUGIN_PATH" "$MU_BCK_PATH" \
                && wget -nv -O "$MU_PLUGIN_PATH" "$MU_PLUGIN_URL"; then
                echo "MU plugin update OK. (${MU_PLUGIN})"
                echo
            else
                echo "MU plugin update failure (${MU_PLUGIN})" >&2
                exit 1
            fi
        else
            echo "MU plugin (${MU_PLUGIN}) has different 'GitHub Plugin URI' (${NEW_GHU_URL})" >&2
            exit 2
        fi
    done
