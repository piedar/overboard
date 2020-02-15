This is a Gentoo [ebuild repository](https://wiki.gentoo.org/wiki/Ebuild_repository) which provides some extra packages.

To use it, create this `/etc/portage/repos.conf/overboard.conf`

```
[overboard]
location = /var/db/repos/overboard/
sync-type = git
sync-uri = https://github.com/piedar/overboard
auto-sync = true
```

then run `sudo emerge --sync`.
