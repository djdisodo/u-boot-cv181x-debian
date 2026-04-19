# Recipe-only Debian packaging

`new_recipe/` is a packaging-only Git repository for SG2002
U-Boot/OpenSBI distroboot firmware packages.

The source package currently builds:

- `u-boot-sg2002-milkv-duo256m-distroboot`
- `u-boot-sg2002-licheerv-nano-distroboot`

Each binary package installs its own board-specific `fip.bin` directly under
`/boot/`, keeps the remaining firmware artifacts under
`/usr/lib/u-boot/<board>/`, installs a board-specific `u-boot-menu` fragment,
and sets U-Boot's default `fdtfile` in the matching defconfig so Debian
extlinux entries can use generic `fdtdir` selection while still resolving to
the correct board DTB.

**Branch model**

- `master`: recipe-only branch. CI builds artifacts only.
- `latest-recipe`: recipe-only branch. CI builds, regenerates the published
  `gbp` branches, pushes them back to GitHub, and publishes `.deb` files to
  `deb-s3`.
- `latest`: generated build branch with unpacked upstream sources plus
  `debian/`.
- `upstream/latest`: imported upstream source branch for `gbp`.
- `pristine-tar`: `pristine-tar` metadata.

The recipe branches intentionally do not contain the upstream source tree. The
generated `latest` branch is reconstructed by CI with `uscan` and
`gbp import-orig`, or by reapplying `debian/` onto the existing imported
upstream branch when the upstream version has not changed.

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
- `DEB_S3_CODENAME`, `DEB_S3_COMPONENT`, `DEB_S3_REGION`, `DEB_S3_ENDPOINT`,
  `DEB_S3_FORCE_PATH_STYLE`, `DEB_S3_PREFIX`, `DEB_S3_ORIGIN`, `DEB_S3_SUITE`,
  `DEB_S3_CLEAN`, `DEB_S3_PRESERVE_VERSIONS`, `DEB_S3_LOCK`, `DEB_S3_FAIL_IF_EXISTS`,
  `DEB_S3_USE_SESSION_TOKEN`, `DEB_S3_VISIBILITY`, `DEB_S3_SIGN_KEY` repo
  variables: optional publish controls. Set `DEB_S3_SIGN_KEY` to a full
  fingerprint or key ID to make `deb-s3` sign both `InRelease` and
  `Release.gpg`.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN` secrets:
  used by `deb-s3`.
- `DEB_REPO_SIGNING_PRIVATE_KEY` secret: optional ASCII-armored or base64
  encoded private OpenPGP key for repository signing.
- `DEB_REPO_SIGNING_PASSPHRASE` secret: optional passphrase for the private
  key. CI passes it to `gpg` through a temporary file with loopback pinentry.

For Cloudflare R2, set for example:

- `DEB_S3_BUCKET=my-r2-bucket`
- `DEB_S3_PREFIX=debian/u-boot`
- `DEB_S3_REGION=auto`
- `DEB_S3_ENDPOINT=https://<account_id>.r2.cloudflarestorage.com`
- `DEB_S3_FORCE_PATH_STYLE=0`

To create a dedicated repository signing key locally:

```sh
gpg --quick-gen-key 'Sodo Repo Signing <repo@example.com>' ed25519 sign 2y
key_id=$(gpg --list-secret-keys --with-colons 'Sodo Repo Signing <repo@example.com>' | awk -F: '/^fpr:/ { print $10; exit }')
gpg --armor --export-secret-keys "$key_id" > repository-signing-private.asc
gpg --armor --export "$key_id" > repository-signing-key.asc
gpg --export "$key_id" > repository-signing-key.gpg
```

Then configure GitHub as follows:

- repo variable `DEB_S3_SIGN_KEY`: set it to the fingerprint in `key_id`, or
  leave it unset and let CI use the first imported secret key.
- repo secret `DEB_REPO_SIGNING_PRIVATE_KEY`: paste the contents of
  `repository-signing-private.asc`.
- repo secret `DEB_REPO_SIGNING_PASSPHRASE`: set it only if the private key is
  passphrase protected.

When signing is enabled, the `latest-recipe` workflow also exports
`repository-signing-key.asc` and `repository-signing-key.gpg` into the uploaded
build artifact so clients can install the public key.

`ci/run-sbuild.sh` will refresh the Debian archive keyring from the official
Debian package pool when bootstrapping a Debian mirror, and you can override
that with `SBUILD_KEYRING=/path/to/keyring.gpg` if you need a custom mirror.

Publish defaults:

- repository locking is enabled by default
- old package versions are removed from manifests by default
- dangling old `.deb` objects are cleaned from the bucket by default
- set `DEB_S3_PRESERVE_VERSIONS=1` to keep old versions
- set `DEB_S3_CLEAN=0` to skip the post-upload `deb-s3 clean`

When using a custom S3 endpoint such as Cloudflare R2:

- `ci/publish-deb-s3.sh` defaults to `--visibility nil` unless you explicitly
  set `DEB_S3_VISIBILITY`, because R2 does not support S3 ACL headers.
- `ci/publish-deb-s3.sh` skips `deb-s3 --lock` by default unless you explicitly
  set `DEB_S3_LOCK=1`, because `deb-s3`'s lock protocol is not consistently
  supported by S3-compatible providers.
- `ci/publish-deb-s3.sh` unsets `AWS_SESSION_TOKEN` by default for custom
  endpoints, because providers such as R2 usually expect only access key and
  secret key. Set `DEB_S3_USE_SESSION_TOKEN=1` only if your endpoint requires it.
- `.github/workflows/latest-recipe.yml` uses workflow `concurrency` so publish
  jobs still run one at a time.
