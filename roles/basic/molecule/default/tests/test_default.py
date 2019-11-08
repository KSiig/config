import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_packages_installed(host):
    git = host.package('git')
    assert git.is_installed

    tmux = host.package('tmux')
    assert tmux.is_installed

    curl = host.package('curl')
    assert curl.is_installed

    python = host.package('python')
    assert python.is_installed

    python3 = host.package('python3')
    assert python3.is_installed

    unzip = host.package('unzip')
    assert unzip.is_installed
