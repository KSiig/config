import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_dependencies(host):
    zsh = host.package('zsh')
    git = host.package('git')

    assert zsh.is_installed
    assert git.is_installed


def test_oh_my_zsh_exists(host):
    d = host.file('/home/ansible/.oh-my-zsh')

    assert d.exists
    assert d.is_directory


def test_plugins_exists(host):
    d = host.file('/home/ansible/.oh-my-zsh/plugins/alias-tips')

    assert d.exists
    assert d.is_directory

    d = host.file('/home/ansible/.oh-my-zsh/plugins/zsh-syntax-highlighting')

    assert d.exists
    assert d.is_directory


def test_config_files(host):
    f = host.file('/home/ansible/.bash_aliases')
    assert f.exists
    assert f.user == 'ansible'
    assert f.group == 'ansible'

    f = host.file('/home/ansible/.kubectl_aliases')
    assert f.exists
    assert f.user == 'ansible'
    assert f.group == 'ansible'

    f = host.file('/home/ansible/.zlogin')
    assert f.exists
    assert f.user == 'ansible'
    assert f.group == 'ansible'

    f = host.file('/home/ansible/.zlogout')
    assert f.exists
    assert f.user == 'ansible'
    assert f.group == 'ansible'

    f = host.file('/home/ansible/.zpreztorc')
    assert f.exists
    assert f.user == 'ansible'
    assert f.group == 'ansible'

    f = host.file('/home/ansible/.zshenv')
    assert f.exists
    assert f.user == 'ansible'
    assert f.group == 'ansible'

    f = host.file('/home/ansible/.zshrc')
    assert f.exists
    assert f.user == 'ansible'
    assert f.group == 'ansible'
