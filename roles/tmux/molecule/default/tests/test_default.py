import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_tmux_installed(host):
    tmux = host.package('tmux')

    assert tmux.is_installed


def test_configs_exists(host):
    f = host.file('/home/ansible/.tmux.conf')
    flocal = host.file('/home/ansible/.tmux.conf.local')

    assert f.exists
    assert flocal.exists
