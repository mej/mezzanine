# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # https://docs.vagrantup.com.
  config.vm.define "mzdevel"
  config.vm.box = "centos/7"
  config.vm.box_check_update = true
  # config.vm.synced_folder "../data", "/vagrant_data"
  # config.vm.hostname = "mzdevel"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "mzdevel"
    vb.gui = false
    vb.memory = "1024"
  end

  config.vm.provision "mzdevel", type: "shell", privileged: true, inline: <<-SHELL
    yum makecache fast
    yum-config-manager --setopt=deltarpm=0 --save
    yum -ty upgrade
    yum -ty install git gcc\* make binutils yum-utils device-mapper-persistent-data lvm2 screen wget curl \
        "perl(CPAN)" "perl(Class::Struct)" "perl(Cwd)" "perl(English)" "perl(Exporter)" "perl(File::Copy)" \
        "perl(File::Find)" "perl(File::Listing)" "perl(File::stat)" "perl(Getopt::Long)" "perl(HTTP::Cookies)" \
        "perl(HTTP::Request)" "perl(IPC::Open3)" "perl(LWP::UserAgent)" "perl(Net::FTP)" "perl(POSIX)" \
        "perl(Sys::Hostname)" "perl(URI)" rpm-devel rpm-build glibc-devel autoconf automake libtool

    cd /root
    export MEZZANINE_PATH="/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/bin"
    git clone https://github.com/mej/mezzanine.git
    cd mezzanine
    perl -I. ./pkgtool -b
    rpm -Uvh mezzanine*4.rpm
    cd /root
    rm -rf mezzanine mezzanine*4.rpm
  SHELL

end
