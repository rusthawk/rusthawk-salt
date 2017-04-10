{%- from "confluence/map.jinja" import confluence with context -%}

# To reduce repetitive user: group: statements
{% macro usrgrp(user) -%}
        - user: {{ user }}
        - group: {{ user }}
{%- endmacro %}

include:
    - util.jre

confluence_user:
    user.present:
        - name: {{ confluence.config.user }}
        - system: True
        - createhome: False
        - gid_from_name: True
        - shell: /bin/bash

confluence_install_dir:
    file.directory:
        - name: {{ confluence.config.install_dir }}
        {{ usrgrp(confluence.config.user) }}
        - makedirs: True
        - dir_mode: 740
        - require:
            - user: confluence_user

confluence_home_dir:
    file.directory:
        - name: {{ confluence.config.home_dir }}
        {{ usrgrp(confluence.config.user) }}
        - makedirs: True
        - dir_mode: 740
        - file_mode: 640
        - recurse:
            - user
            - group
            - mode
        - require:
            - user: confluence_user

confluence_install:
    archive.extracted:
        - name: {{ confluence.config.install_dir }}
        - source: {{ confluence.config.archive }}
        - source_hash: sha1=0915890039535f831ed5ff44b70288cb97638d69 
        {{ usrgrp(confluence.config.user) }}
        - options: --strip-components=1
        - require:
            - file: confluence_install_dir
            - user: confluence_user
    file.directory:
        - name: {{ confluence.config.install_dir }}
        {{ usrgrp(confluence.config.user) }}
        - recurse:
            - user
            - group
        - require:
            - archive: confluence_install
            - user: confluence_user

confluence_homedir_setting:
    file.managed:
        - name: {{ confluence.config.install_dir }}/confluence/WEB-INF/classes/confluence-init.properties
        - source: salt://confluence/templates/confluence-init.properties.jinja
        - template: jinja
        - replace: True
        {{ usrgrp(confluence.config.user) }}
        - mode: 740
        - defaults:
            home_dir: {{ confluence.config.home_dir }}
        - require:
            - file: confluence_home_dir

confluence_server_xml_setting:
    file.managed:
        - name: {{ confluence.config.install_dir }}/conf/server.xml
        - source: salt://confluence/templates/server.xml.jinja
        - template: jinja
        - replace: True
        {{ usrgrp(confluence.config.user) }}
        - mode: 640
        - defaults:
            proxy: True
            context_path: {{ confluence.proxy.get('context_path', '') }}
            proxy_name: {{ confluence.proxy.proxy_name }}
            proxy_port: {{ confluence.proxy.proxy_port }}
            proxy_scheme: {{ confluence.proxy.proxy_scheme }}

confluence_service:
    file.managed:
        - name: /etc/systemd/system/confluence.service
        - source: salt://confluence/templates/confluence.service.jinja
        - template: jinja
        - replace: True
        {{ usrgrp('root') }}
        - mode: 640
        - defaults:
            install_dir: {{ confluence.config.install_dir }}
            confluence_user: {{ confluence.config.user }}
    module.run:
        - name: service.systemctl_reload
        - onchanges:
            - file: confluence_service
    service.running:
        - name: confluence.service
        - enable: True
        - require:
            - pkg: jre_installed
        - watch:
            - file: confluence_server_xml_setting
            - file: confluence_homedir_setting