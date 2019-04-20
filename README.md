# Infrastructure Security Tools

[![Build Status](https://travis-ci.com/AASAAM/infrastructure-security-tools.svg?branch=master)](https://travis-ci.com/AASAAM/infrastructure-security-tools)

Lets add some security workflow.

## Story

In our infrastructure we have some problem that need to be solved.

* We need to have TLS communication between services.
* Developers and system administrators must take care of the security workflows.

## Requirement

Fresh installation of any GNU/Linux with following packages:

* coreutils
* faketime
* gpgv2
* openssh-client
* openssl
* python

Note:

* Better to use live version of latest OS and disconnect from any network before you begin.
* After generate the keys store files on secure physical place and device like usb stick.
* You can also create encrypted usb to store files [Guide](https://www.howtoforge.com/tutorial/encrypt-usb-drive-on-ubuntu/)

## Guide

For create the root ca and intermediate ca just bring empty pc with no internet connection.

* Install requirements.
* View `lib/includes.sh` and you can overwrite to `config.sh` env variables.
* Edit template files for name of ca `templates/*.ini`.
* Run `gen-ca.sh` to generate root certificate authority and intermediate certificate authority.
* Run `gen-servers.sh` to generate servers certificates and SSH keys.
* Run `gen-user-sysadmin.sh` for system administrators certificate, SSH and GPG for system administrators.
* Run `gen-user-developer.sh` for developers, SSH and GPG.

Developer can easily use stuff for making their own security stuff.

## Usage

Install root ca to client, you can serve `public/aasaam-root-ca.crt`, `public/aasaam-root-ca.pem` to whole world.

* [Firefox](https://www.cyberciti.biz/faq/firefox-adding-trusted-ca/)
* [Android](https://support.google.com/nexus/answer/2844832?hl=en)
* [Ubuntu](https://superuser.com/questions/437330/how-do-you-add-a-certificate-authority-ca-to-ubuntu)
* [Windows](https://docs.microsoft.com/en-us/skype-sdk/sdn/articles/installing-the-trusted-root-certificate)

## TLS Services

Generated server keys are two part 2048 and 4096 for CPU usage.
After generation files are in `output/servers`.

Notes:

* File start with `server_local` is for local domains.
* Files start with `server_internal` for internal TLS like databases and sign with root ca.
* Other files like `server_[0-9]` sign by intermediate and good for using on public TLS servers like web servers.

### Benchmark key size

Run command and show the result on your own device.

```bash
openssl speed rsa
```

Sample result on **Intel(R) Core(TM) i7-7700HQ CPU @ 2.80GHz**

```txt
                    sign    verify   sign/s verify/s
rsa 2048  bits 0.000622s 0.000017s   1607.2  59151.8
rsa 4096  bits 0.004087s 0.000063s    244.7  15944.2
```

## Disclaimer

Use this project at your own risk, and we happy to open issue for achieve better solution.

As you know for internal infrastructure always protect your services with firewall.

## More info

* [OpenSSL](https://www.openssl.org/docs/)
* [OpenSSH](https://www.openssh.com/manual.html)
* [GnuPG](https://www.gnupg.org/documentation/manuals/gnupg/)
