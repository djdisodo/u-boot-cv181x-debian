# Recipe-only Debian packaging

`new_recipe/` is a packaging-only Git repository for the Milk-V Duo 256M
U-Boot/OpenSBI firmware package.

**Branch model**

- `master`: recipe-only branch. CI builds artifacts only.
- `latest-recipe`: recipe-only branch. CI builds, regenerates the published
  `gbp` branches, pushes them back to GitHub, and publishes `.deb` files to
  `deb-s3`.
- `latest`: generated build branch with unpacked upstream sources plus the
  packaging files from the recipe branch.
- `upstream/latest`: imported upstream source branch for `gbp`.
- `pristine-tar`: `pristine-tar` metadata.

The recipe branches intentionally do not contain the upstream source tree. The
generated `latest` branch is reconstructed by CI with `uscan` and
`gbp import-orig`, or by re-overlaying the full recipe branch onto the
existing imported upstream branch when the upstream version has not changed.

**Local build flow**

```sh
cd /root/uboot/new_recipe
git fetch github latest upstream/latest pristine-tar --tags || true
git worktree add ../latest-build github/master
cd ../latest-build
version=$(dpkg-parsechangelog --show-field Version | sed 's/-[^-]*$//')
uscan --check-dirname-level 0 --download-current-version --rename --destdir ..
gbp import-orig --no-interactive --debian-branch=latest \
  --upstream-branch=upstream/latest --upstream-version "$version" \
  ../u-boot-sg2002-milkv-duo256m-distroboot_${version}.orig.tar.xz
dpkg-buildpackage -us -uc -b
```

For patch maintenance, make changes in the imported source tree and record them
with `dpkg-source --commit`.

**CI inputs**

- `DEB_S3_BUCKET` repo variable: required for `deb-s3` publishing.
- `DEB_S3_CODENAME`, `DEB_S3_COMPONENT`, `DEB_S3_REGION`, `DEB_S3_PREFIX`,
  `DEB_S3_ORIGIN`, `DEB_S3_SUITE`, `DEB_S3_PRESERVE_VERSIONS`, `DEB_S3_LOCK`,
  `DEB_S3_FAIL_IF_EXISTS`, `DEB_S3_VISIBILITY` repo variables: optional publish
  controls.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` secrets:
  used by `deb-s3`.
