import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']
).get_hosts('all')


def test_ppa_added(host):
    f = host.file('/etc/apt/sources.list.d/ppa_neovim_ppa_stable_bionic.list')
    assert f.exists


def test_neovim_installed(host):
    neovim = host.package("neovim")
    assert neovim.is_installed


def test_config_folder(host):
    d = host.file('/home/ansible/.config/nvim')
    assert d.exists
    assert d.is_directory
    assert d.user == 'ansible'
    assert d.group == 'ansible'
    assert d.mode == 0o744


def test_config_file(host):
    f = host.file('/home/ansible/.config/nvim/init.vim')
    assert f.exists
    assert f.is_file
    assert f.user == 'ansible'
    assert f.group == 'ansible'
    assert f.mode == 0o644


def test_vimplug_folder(host):
    d = host.file('/home/ansible/.local/share/nvim/site/autoload')
    assert d.exists
    assert d.is_directory
    assert d.user == 'ansible'
    assert d.group == 'ansible'
    assert d.mode == 0o744


def test_vimplug_file(host):
    f = host.file('/home/ansible/.local/share/nvim/site/autoload/plug.vim')
    assert f.exists
    assert f.is_file
    assert f.user == 'ansible'
    assert f.group == 'ansible'
    assert f.mode == 0o644


def test_git_installed(host):
    git = host.package('git')
    assert git.is_installed


def test_plugin_folder(host):
    d = host.file('/home/ansible/.local/share/nvim/plugged/nerdtree')
    assert d.exists
    assert d.is_directory
    assert d.user == 'ansible'
    assert d.group == 'ansible'
    assert d.mode == 0o755
