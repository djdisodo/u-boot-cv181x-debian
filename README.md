# Recipe-only Debian packaging

`new_recipe/` is a packaging-only Git repository for the Milk-V Duo 256M
U-Boot/OpenSBI firmware package.

This checkout intentionally does not contain the upstream source tree. If you
import upstream directly into this checkout with `gbp import-orig`, the working
tree becomes a normal Debian source tree. To keep `new_recipe/` recipe-only,
run the import in a disposable clone.

Typical local flow:

```sh
cd /root/uboot
gbp clone --debian-branch=debian/latest --upstream-branch=upstream/latest \
  ./new_recipe build/u-boot-sg2002-milkv-duo256m-distroboot-gbp
cd build/u-boot-sg2002-milkv-duo256m-distroboot-gbp
version=$(dpkg-parsechangelog --show-field Version | sed 's/-[^-]*$//')
uscan --check-dirname-level 0 --download-current-version --rename --destdir ..
gbp import-orig --no-interactive --upstream-version "$version" \
  ../u-boot-sg2002-milkv-duo256m-distroboot_${version}.orig.tar.xz
dpkg-buildpackage -us -uc -b
```

If you want a Debian source package as well:

```sh
dpkg-source -b .
```

For patch maintenance, make changes in the imported source tree and record them
with:

```sh
dpkg-source --commit
```
