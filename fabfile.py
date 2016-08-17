#!/usr/bin/env python

# Install and deploy service to custom host.
# The host should have 'altexo' user and the user should have sudo.
# Project is installed to /srv/altexo/signal by cloning git repo.
# Symbolic link from /var/www/ is created.
# Project process is managed by supervisor.

from fabric.api import *
from fabric.contrib.files import exists, is_link
from fabric.contrib.project import rsync_project

STAGES = {
    'production': {
        'hosts': ['altexo@altexo.com'],
        'config_script': 'scripts/config/setup_env_production'
    },
    'testing': {
        'hosts': ['altexo@dev.lugati.ru'],
        'config_script': 'scripts/config/setup_env_testing'
    },
    'virtual': {
        'hosts': ['altexo@localhost:2222'],
        'config_script': 'scripts/config/setup_env_development'
    }
}

def stage_set(stage_name):
    env.stage = stage_name
    for option, value in STAGES[env.stage].items():
        setattr(env, option, value)

@task
def production():
    stage_set('production')

@task
def testing():
    stage_set('testing')

@task
def virtual():
    stage_set('virtual')

@task
def install():
    require('stage', provided_by=(production, testing, virtual,))

    if not exists('/srv/altexo/signal'):
        install_project()
    if not exists('/etc/supervisor/conf.d/altexo-signal.conf'):
        install_supervisor_conf()
    if not exists('/srv/altexo/_nginx_conf/signal.conf'):
        install_nginx_conf()

@task
def uninstall():
    require('stage', provided_by=(production, testing, virtual,))

    uninstall_nginx_conf()
    uninstall_supervisor_conf()
    uninstall_project()

@task
def install_project():
    require('stage', provided_by=(production, testing, virtual,))

    sudo('mkdir -p /srv/altexo')
    sudo('chown altexo:altexo /srv/altexo')
    if not is_link('/var/www/altexo'):
        sudo('mkdir -p /var/www')
        sudo('chown www-data:www-data /var/www')
        sudo('ln -s /srv/altexo /var/www/altexo')
    with cd('/srv/altexo'):
        run('git clone git@bitbucket.org:altexo/altexo-signal-node.git signal')
    with cd('/srv/altexo/signal'):
        run('source ~/.nvm/nvm.sh && npm install')

@task
def uninstall_project():
    require('stage', provided_by=(production, testing, virtual,))

    run('rm -rf /srv/altexo/signal')

@task
def install_supervisor_conf():
    require('stage', provided_by=(production, testing, virtual,))

    with cd('/srv/altexo/signal'):
        sudo('cp scripts/config/supervisor.conf /etc/supervisor/conf.d/altexo-signal.conf')
        sudo('supervisorctl reread')
        sudo('supervisorctl update')

@task
def uninstall_supervisor_conf():
    require('stage', provided_by=(production, testing, virtual,))

    sudo('rm /etc/supervisor/conf.d/altexo-signal.conf')
    sudo('supervisorctl reread')
    sudo('supervisorctl update')

@task
def install_nginx_conf():
    require('stage', provided_by=(production, testing, virtual,))

    sudo('mkdir -p /srv/altexo/_nginx_conf')
    with cd('/srv/altexo/signal'):
       sudo('cp scripts/config/nginx-locations.conf /srv/altexo/_nginx_conf/signal.conf')

@task
def uninstall_nginx_conf():
    require('stage', provided_by=(production, testing, virtual,))

    sudo('rm -f /srv/altexo/_nginx_conf/signal.conf')
    sudo('service nginx restart')


@task
def deploy():
    require('stage', provided_by=(production, testing, virtual,))

    with cd('/srv/altexo/signal'):
        run('git checkout .')
        run('git pull')
        run('rm -f scripts/setup_env && ln -rs ./%s scripts/setup_env' % env.config_script)
        run('source ~/.nvm/nvm.sh && npm update')

    sudo('supervisorctl restart altexo-signal')
    sudo('service nginx restart')


@task
def deploy_rsync():
    require('stage', provided_by=(testing, virtual,))

    rsync_project(local_dir='.', remote_dir='/srv/altexo/signal/',
        exclude=['.git/', 'node_modules/', '__pycache__/', '*.pyc'],
        default_opts='-pvthrz', delete=True)

    with cd('/srv/altexo/signal'):
        run('rm -f scripts/setup_env && ln -rs ./%s scripts/setup_env' % env.config_script)
        # run('source ~/.nvm/nvm.sh && npm update')

    # sudo('supervisorctl restart altexo-signal')
    # sudo('service nginx restart')

