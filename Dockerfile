FROM barichello/godot-ci:4.4.1 AS build
WORKDIR /src
COPY godot/ /src/godot/

RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl unzip ca-certificates; \
    TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/4.4.1.stable"; \
    mkdir -p "$TEMPLATE_DIR"; \
    curl --fail --location --retry 3 \
      "https://github.com/godotengine/godot/releases/download/4.4.1-stable/Godot_v4.4.1-stable_export_templates.tpz" \
      --output /tmp/godot-export-templates.tpz; \
    unzip -j -o /tmp/godot-export-templates.tpz \
      "templates/web_nothreads_debug.zip" \
      "templates/web_nothreads_release.zip" \
      -d "$TEMPLATE_DIR"; \
    test -s "$TEMPLATE_DIR/web_nothreads_release.zip"; \
    godot --headless --editor --path /src/godot --import; \
    mkdir -p /out; \
    godot --headless --path /src/godot --export-release "Web" /out/index.html; \
    test -s /out/index.html

FROM nginx:1.27-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /out/ /usr/share/nginx/html/
EXPOSE 8080
