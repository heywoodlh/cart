#!/usr/bin/env zsh
set -e

work_dir="/tmp/cart-test"
fixture_dir="${work_dir}/fixtures"
apps_dir="${work_dir}/Applications"
rm -rf "${work_dir}" /tmp/cart.config
mkdir -p "${fixture_dir}" "${work_dir}/bin"

cat >/tmp/cart.config <<EOL
downloads="${work_dir}/downloads"
mountpoints="${work_dir}/mountpoints"
local_file="false"
apps_folder="${apps_dir}"
cart_dir="${work_dir}"
github_api="file://${fixture_dir}/github"
EOL

# Cart uses jq for its installed-app registry and repository lists. Keep this
# suite offline by supplying a small JSON-compatible test double for only the
# jq expressions Cart runs.
cat >"${work_dir}/bin/jq" <<'EOF'
#!/usr/bin/perl
use strict;
use warnings;
use JSON::PP qw(decode_json encode_json);

my $raw = 0;
my $exit_status = 0;
my ( $filter, @files );

while (@ARGV) {
    my $arg = shift @ARGV;
    if    ( $arg eq '-r' || $arg eq '--raw-output' ) { $raw = 1 }
    elsif ( $arg eq '-e' || $arg eq '--exit-status' ) { $exit_status = 1 }
    elsif ( !defined $filter ) { $filter = $arg }
    else { push @files, $arg }
}
die "test jq: no filter provided\n" unless defined $filter;

my $input;
{
    local $/;
    if (@files) {
        open my $fh, '<', $files[0] or die "test jq: cannot read $files[0]: $!\n";
        $input = <$fh>;
        close $fh;
    } else {
        $input = <STDIN>;
    }
}
my $data = decode_json( length( $input // '' ) ? $input : '[]' );

my $any_truthy = 0;

sub emit {
    my ($value) = @_;
    if ( !defined $value ) {
        print "null\n";
        return 0;
    }
    if ( ref($value) eq 'JSON::PP::Boolean' ) {
        my $truthy = $value ? 1 : 0;
        print( $truthy ? "true\n" : "false\n" );
        return $truthy;
    }
    if ( ref($value) ) {
        print encode_json($value), "\n";
        return 1;
    }
    print $value, "\n";
    return 1;
}

sub field {
    my ( $value, $name ) = @_;
    return undef unless ref($value) eq 'HASH';
    return $value->{$name};
}

if ( $filter =~ /^\. \+= \[ (\{.*\}) \]$/s ) {
    push @{$data}, decode_json($1);
    print encode_json($data);
}
elsif ( $filter =~ /^del\(\.\[\] \| select\(\.name\s*==\s*"([^"]*)"\)\)$/ ) {
    my $name = $1;
    print encode_json( [ grep { $_->{name} ne $name } @{$data} ] );
}
elsif ( $filter =~ /^\.\[\] \| select\(\.name\s*==\s*"([^"]*)"\)$/ ) {
    my $name = $1;
    for my $item ( grep { ref($_) eq 'HASH' && ( $_->{name} // '' ) eq $name } @{$data} ) {
        $any_truthy = 1;
        print encode_json($item), "\n";
    }
}
elsif ( $filter =~ /^(\.\[\]|\.([A-Za-z0-9_]+)\[\]) \| \[([^]]+)\] \| \@tsv$/ ) {
    my $array_key = $2;
    my $fields    = $3;
    my $list = defined $array_key ? field( $data, $array_key ) : $data;
    die "test jq: $filter expects an array\n" unless ref($list) eq 'ARRAY';
    my @names = map { ( my $n = $_ ) =~ s/^\.//; $n } split /\s*,\s*/, $fields;
    for my $item ( @{$list} ) {
        next unless ref($item) eq 'HASH';
        my @values = map { defined $item->{$_} ? $item->{$_} : '' } @names;
        print join( "\t", @values ), "\n";
    }
}
elsif ( $filter =~ /^\.\[\]\.([A-Za-z0-9_]+)$/ ) {
    my $name = $1;
    for my $item ( @{$data} ) {
        $any_truthy = 1 if emit( field( $item, $name ) );
    }
}
elsif ( $filter =~ /^\.([A-Za-z0-9_]+)$/ ) {
    $any_truthy = emit( field( $data, $1 ) );
}
elsif ( $filter eq '.' ) {
    print encode_json($data), "\n";
    $any_truthy = 1;
}
else {
    die "Unsupported test jq filter: $filter\n";
}

if ($exit_status) {
    exit( $any_truthy ? 0 : 1 );
}
EOF
chmod +x "${work_dir}/bin/jq"

export cart_debug="true"
export CART_CONFIG=/tmp/cart.config

make_app_tree() {
    tree="$1"
    layout="$2"
    app_name="$3"
    case "${layout}" in
        root) app_path="${tree}/${app_name}.app" ;;
        direct) app_path="${tree}/test.app" ; app_name="test" ;;
        nested) app_path="${tree}/out/test.app" ; app_name="test" ;;
        *) return 1 ;;
    esac
    mkdir -p "${app_path}/Contents"
    printf '%s\n' "${tree}-${layout}" > "${app_path}/Contents/fixture.txt"
    printf '%s\n' "${app_name}" > "${tree}/expected-app-name"
}

assert_cart_install() {
    archive="$1"
    expected_app="$2"
    hash="$(shasum -a 256 "${archive}" | awk '{print $1}')"
    ./cart add "${archive}" "${hash}"
    ./cart list | grep -Fxq "${expected_app}"
    [[ -f "${apps_dir}/${expected_app}.app/Contents/fixture.txt" ]]
    ./cart del "${expected_app}"
    [[ ! -e "${apps_dir}/${expected_app}.app" ]]
}

create_and_test_archives() {
    format="$1"
    layout="$2"
    app_name="${format}-${layout}"
    tree="${fixture_dir}/${format}-${layout}"
    make_app_tree "${tree}" "${layout}" "${app_name}"
    expected_app="${app_name}"
    [[ "${layout}" == root ]] || expected_app="test"

    case "${format}" in
        dmg)
            archive="${fixture_dir}/${format}-${layout}.dmg"
            hdiutil create -quiet -fs HFS+ -srcfolder "${tree}" -format UDZO -ov "${archive}"
        ;;
        dmg-lzfse)
            # LZFSE images report as application/octet-stream to file(1), so magic
            # matching missed them (issue #15).
            archive="${fixture_dir}/${format}-${layout}.dmg"
            hdiutil create -quiet -fs HFS+ -srcfolder "${tree}" -format ULFO -ov "${archive}"
        ;;
        tar-gz)
            archive="${fixture_dir}/${format}-${layout}.tar.gz"
            /usr/bin/tar -czf "${archive}" -C "${tree}" .
        ;;
        tar)
            archive="${fixture_dir}/${format}-${layout}.tar"
            /usr/bin/tar -cf "${archive}" -C "${tree}" .
        ;;
        tar-bz2)
            archive="${fixture_dir}/${format}-${layout}.tar.bz2"
            /usr/bin/tar -cjf "${archive}" -C "${tree}" .
        ;;
        tar-xz)
            archive="${fixture_dir}/${format}-${layout}.tar.xz"
            /usr/bin/tar -cJf "${archive}" -C "${tree}" .
        ;;
        zip)
            archive="${fixture_dir}/${format}-${layout}.zip"
            (cd "${tree}" && /usr/bin/zip -qr "${archive}" .)
        ;;
        xz)
            disk_image="${fixture_dir}/${format}-${layout}.dmg"
            archive="${disk_image}.xz"
            hdiutil create -quiet -fs HFS+ -srcfolder "${tree}" -format UDZO -ov "${disk_image}"
            xz -zkf "${disk_image}"
        ;;
        pkg)
            archive="${fixture_dir}/${format}-${layout}.pkg"
            if [[ "${layout}" == root ]]
            then
                scripts_dir="${fixture_dir}/${format}-${layout}-scripts"
                mkdir -p "${scripts_dir}"
                cat >"${scripts_dir}/postinstall" <<'EOF'
#!/bin/sh
printf 'executed\n' > /tmp/cart-test/pkg-script-ran
EOF
                chmod +x "${scripts_dir}/postinstall"
                pkgbuild --root "${tree}" --scripts "${scripts_dir}" --identifier "com.cart.test.${format}.${layout}" --version 1.0 --install-location Applications "${archive}"
            else
                pkgbuild --root "${tree}" --identifier "com.cart.test.${format}.${layout}" --version 1.0 --install-location Applications "${archive}"
            fi
        ;;
        *) return 1 ;;
    esac
    assert_cart_install "${archive}" "${expected_app}"
    if [[ "${format}" == pkg && "${layout}" == root ]]
    then
        [[ ! -e "${work_dir}/pkg-script-ran" ]]
    fi
}

for format in dmg dmg-lzfse tar tar-gz tar-bz2 tar-xz zip xz pkg
do
    for layout in root direct nested
    do
        create_and_test_archives "${format}" "${layout}"
    done
done

# Archives without an app fail and do not leave temporary extraction state.
mkdir -p "${fixture_dir}/no-app/out"
printf 'no app\n' > "${fixture_dir}/no-app/out/README.txt"
/usr/bin/tar -cJf "${fixture_dir}/no-app.tar.xz" -C "${fixture_dir}/no-app" .
if ./cart add "${fixture_dir}/no-app.tar.xz"
then
    exit 20
fi
[[ ! -e "${work_dir}/mountpoints/no-app.tar.xz" ]] || exit 21

# Archive traversal entries are rejected before extraction.
/usr/bin/tar -cJf "${fixture_dir}/traversal.tar.xz" -s ',^,../,' -C "${fixture_dir}/no-app" .
if ./cart add "${fixture_dir}/traversal.tar.xz" > "${fixture_dir}/traversal.out" 2>&1
then
    exit 22
fi
grep -Fq "Unsafe archive member" "${fixture_dir}/traversal.out"
[[ ! -e "${work_dir}/mountpoints/traversal.tar.xz" ]] || exit 23

# Invalid XZ disk images must fail without leaving decompressed or downloaded files.
printf 'not a disk image' > "${fixture_dir}/invalid.dmg"
xz -zkf "${fixture_dir}/invalid.dmg"
if ./cart add "file://${fixture_dir}/invalid.dmg.xz"
then
    exit 24
fi
[[ ! -e "${work_dir}/downloads/invalid.dmg" ]]
[[ ! -e "${work_dir}/downloads/invalid.dmg.xz" ]]

# ---------------------------------------------------------------------------
# Repository support (issue #17)
# ---------------------------------------------------------------------------

make_zip_app() {
    tree="$1"
    app="$2"
    archive="$3"
    mkdir -p "${tree}/${app}.app/Contents"
    printf '%s\n' "${app}" > "${tree}/${app}.app/Contents/fixture.txt"
    rm -f "${archive}"
    (cd "${tree}" && /usr/bin/zip -qr "${archive}" .)
}

write_repo() {
    dest="$1"
    name="$2"
    app="$3"
    url="$4"
    hash="$5"
    cat >"${dest}" <<EOF
{
  "name": "${name}",
  "apps": [
    { "name": "${app}", "url": "${url}", "hash": "${hash}" }
  ]
}
EOF
}

sha256_of() {
    shasum -a 256 "$1" | awk '{print $1}'
}

repo_app_dir="${fixture_dir}/repo-app"
signed_app_dir="${fixture_dir}/signed-app"
widget_app_dir="${fixture_dir}/widget-app"
make_zip_app "${repo_app_dir}" "RepoApp" "${fixture_dir}/RepoApp.zip"
make_zip_app "${signed_app_dir}" "SignedApp" "${fixture_dir}/SignedApp.zip"
make_zip_app "${widget_app_dir}" "Widget" "${fixture_dir}/Widget.zip"
repo_app_hash="$(sha256_of "${fixture_dir}/RepoApp.zip")"
signed_app_hash="$(sha256_of "${fixture_dir}/SignedApp.zip")"
widget_hash="$(sha256_of "${fixture_dir}/Widget.zip")"

# A local repository list installs by application name.
write_repo "${fixture_dir}/one-repo.json" "one" "RepoApp" "file://${fixture_dir}/RepoApp.zip" "${repo_app_hash}"
./cart repo add "file://${fixture_dir}/one-repo.json"
./cart repo list | grep -Fq "one"
[[ -f "${work_dir}/repos/one.json" ]]
./cart add RepoApp
./cart list | grep -Fxq "RepoApp"
[[ -f "${apps_dir}/RepoApp.app/Contents/fixture.txt" ]]
./cart del RepoApp
[[ ! -e "${apps_dir}/RepoApp.app" ]]

# The hash pinned in the repository is enforced for the download itself.
if ./cart add RepoApp "0000000000000000000000000000000000000000000000000000000000000000" > "${fixture_dir}/bad-app-hash.out" 2>&1
then
    exit 30
fi
grep -Fq "Incorrect file hash provided" "${fixture_dir}/bad-app-hash.out"

# Re-adding a configured repository points at `repo update` instead.
if ./cart repo add "file://${fixture_dir}/one-repo.json" > /dev/null 2>&1
then
    exit 31
fi

# An unchanged list updates cleanly.
./cart repo update one | grep -Fq "Updated repository one"

# Content that changes without a pinned key or hash is a suspected MITM.
cat >"${fixture_dir}/one-repo.json" <<EOF
{
  "name": "one",
  "apps": [
    { "name": "RepoApp", "url": "file://${fixture_dir}/RepoApp.zip", "hash": "${repo_app_hash}" },
    { "name": "RepoAppTwo", "url": "file://${fixture_dir}/RepoApp.zip", "hash": "${repo_app_hash}" }
  ]
}
EOF
if ./cart repo update one > "${fixture_dir}/update-unsigned.out" 2>&1
then
    exit 32
fi
grep -Fq "possible MITM" "${fixture_dir}/update-unsigned.out"
if ./cart add RepoAppTwo > /dev/null 2>&1
then
    exit 33
fi

# Accepting the new content explicitly updates the pinned hash.
one_repo_hash="$(sha256_of "${fixture_dir}/one-repo.json")"
./cart repo update one --hash "${one_repo_hash}" | grep -Fq "Updated repository one"
./cart add RepoAppTwo
./cart list | grep -Fxq "RepoApp"
./cart del RepoApp

# Repositories can be signed; the pinned key is verified on add and update.
openssl genrsa -out "${fixture_dir}/repo-key.pem" 2048 > /dev/null 2>&1
openssl rsa -in "${fixture_dir}/repo-key.pem" -pubout -out "${fixture_dir}/repo-key.pub" > /dev/null 2>&1
write_repo "${fixture_dir}/signed.json" "signed" "SignedApp" "file://${fixture_dir}/SignedApp.zip" "${signed_app_hash}"
openssl dgst -sha256 -sign "${fixture_dir}/repo-key.pem" -out "${fixture_dir}/signed.json.sig" "${fixture_dir}/signed.json"
./cart repo add "file://${fixture_dir}/signed.json" --key "${fixture_dir}/repo-key.pub"
./cart add SignedApp
./cart list | grep -Fxq "SignedApp"
./cart del SignedApp

# A tampered list is rejected because the signature no longer matches.
signed_repo_original="$(cat "${fixture_dir}/signed.json")"
cat >"${fixture_dir}/signed.json" <<EOF
{
  "name": "signed",
  "apps": [
    { "name": "SignedApp", "url": "file://${fixture_dir}/SignedApp.zip", "hash": "${signed_app_hash}" },
    { "name": "SignedAppTwo", "url": "file://${fixture_dir}/SignedApp.zip", "hash": "${signed_app_hash}" }
  ]
}
EOF
if ./cart repo update signed > "${fixture_dir}/update-tampered.out" 2>&1
then
    exit 34
fi
grep -Fq "Signature verification failed" "${fixture_dir}/update-tampered.out"
if ./cart add SignedAppTwo > /dev/null 2>&1
then
    exit 35
fi

# Re-signing restores updates with the pinned key.
openssl dgst -sha256 -sign "${fixture_dir}/repo-key.pem" -out "${fixture_dir}/signed.json.sig" "${fixture_dir}/signed.json"
./cart repo update signed | grep -Fq "Updated repository signed"
./cart add SignedAppTwo
./cart del SignedApp

# An invalid signature is refused on add.
printf '%s\n' "${signed_repo_original}" > "${fixture_dir}/bad-signed.json"
openssl dgst -sha256 -sign "${fixture_dir}/repo-key.pem" -out "${fixture_dir}/bad-signed.json.sig" "${fixture_dir}/one-repo.json"
if ./cart repo add "file://${fixture_dir}/bad-signed.json" --key "${fixture_dir}/repo-key.pub" > "${fixture_dir}/add-badsig.out" 2>&1
then
    exit 36
fi
grep -Fq "Signature verification failed" "${fixture_dir}/add-badsig.out"

# Repository entries must carry a sha256 hash.
cat >"${fixture_dir}/nohash.json" <<EOF
{ "name": "nohash", "apps": [ { "name": "NoHash", "url": "file://${fixture_dir}/RepoApp.zip" } ] }
EOF
if ./cart repo add "file://${fixture_dir}/nohash.json" > "${fixture_dir}/add-nohash.out" 2>&1
then
    exit 37
fi
grep -Fq "must provide a sha256 hash" "${fixture_dir}/add-nohash.out"

# Non-JSON repository lists are refused.
printf 'not a repository\n' > "${fixture_dir}/notjson.json"
if ./cart repo add "file://${fixture_dir}/notjson.json" > "${fixture_dir}/add-notjson.out" 2>&1
then
    exit 38
fi
grep -Fq "has no apps list" "${fixture_dir}/add-notjson.out"

# Invalid repository names are refused.
if ./cart repo add "file://${fixture_dir}/one-repo.json" --name "bad name" > /dev/null 2>&1
then
    exit 39
fi

# An application provided by two repositories must be disambiguated.
write_repo "${fixture_dir}/two-repo.json" "two" "RepoApp" "file://${fixture_dir}/RepoApp.zip" "${repo_app_hash}"
./cart repo add "file://${fixture_dir}/two-repo.json"
if ./cart add RepoApp > "${fixture_dir}/ambiguous.out" 2>&1
then
    exit 40
fi
grep -Fq "multiple repositories" "${fixture_dir}/ambiguous.out"
./cart add two/RepoApp
./cart list | grep -Fxq "RepoApp"
./cart del RepoApp

# GitHub release helper builds a list from release assets.
mkdir -p "${fixture_dir}/github/repos/acme/widget/releases/tags"
cat >"${fixture_dir}/github/repos/acme/widget/releases/latest" <<EOF
{
  "tag_name": "v1.0.0",
  "assets": [
    { "name": "Widget.zip", "browser_download_url": "file://${fixture_dir}/Widget.zip", "digest": "sha256:${widget_hash}" },
    { "name": "Widget.pkg", "browser_download_url": "file://${fixture_dir}/Widget.zip", "digest": "sha256:${widget_hash}" },
    { "name": "notes.txt", "browser_download_url": "file://${fixture_dir}/notes.txt", "digest": "sha256:${widget_hash}" },
    { "name": "NoDigest.zip", "browser_download_url": "file://${fixture_dir}/Widget.zip", "digest": null }
  ]
}
EOF
cat >"${fixture_dir}/github/repos/acme/widget/releases/tags/v9.9.9" <<EOF
{
  "tag_name": "v9.9.9",
  "assets": [
    { "name": "Widget.zip", "browser_download_url": "file://${fixture_dir}/Widget.zip", "digest": "sha256:${widget_hash}" }
  ]
}
EOF
./cart repo add github:acme/widget
[[ -f "${work_dir}/repos/widget.json" ]]
grep -Fq '"name":"Widget"' "${work_dir}/repos/widget.json"
if grep -Fq "NoDigest" "${work_dir}/repos/widget.json"
then
    exit 41
fi
if grep -Fq "notes" "${work_dir}/repos/widget.json"
then
    exit 42
fi
widget_entries="$(grep -o '"name":"Widget"' "${work_dir}/repos/widget.json" | wc -l | tr -d ' ')"
[[ "${widget_entries}" == "1" ]] || exit 46
./cart add widget/Widget
./cart list | grep -Fxq "Widget"
./cart del Widget

# GitHub repositories refresh from the release API on update.
cat >"${fixture_dir}/github/repos/acme/widget/releases/latest" <<EOF
{
  "tag_name": "v1.1.0",
  "assets": [
    { "name": "Widget.zip", "browser_download_url": "file://${fixture_dir}/Widget.zip", "digest": "sha256:${widget_hash}" }
  ]
}
EOF
./cart repo update widget | grep -Fq "Updated repository widget"
grep -Fq '"tag":"v1.1.0"' "${work_dir}/repos/widget.json"

# A tagged GitHub release can be pinned explicitly.
./cart repo add github:acme/widget@v9.9.9 --name widget-tagged
grep -Fq '"tag":"v9.9.9"' "${work_dir}/repos/widget-tagged.json"

# Removing a repository removes its list and stops name resolution.
./cart repo del widget
[[ ! -e "${work_dir}/repos/widget.json" ]]
if ./cart add widget/Widget > /dev/null 2>&1
then
    exit 43
fi
if ./cart repo del widget > /dev/null 2>&1
then
    exit 44
fi
./cart repo list | grep -Fq "signed"
if ./cart repo list | awk -F '\t' '$1 == "widget" { found = 1 } END { exit !found }'
then
    exit 45
fi

# `cart clean` removes transient state but keeps the app list and repositories.
./cart clean | grep -Fq "Excluding the following files from deletion"
[[ -f "${work_dir}/applist.json" ]]
[[ -f "${work_dir}/repositories.json" ]]
[[ -f "${work_dir}/repos/one.json" ]]

rm -rf "${work_dir}" /tmp/cart.config
