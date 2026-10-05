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
EOL

# Cart uses jq for its installed-app registry. Keep this suite offline by
# supplying a small JSON-compatible test double for only Cart's jq queries.
cat >"${work_dir}/bin/jq" <<'EOF'
#!/usr/bin/perl
use strict;
use warnings;
use JSON::PP qw(decode_json encode_json);

my $raw = @ARGV && $ARGV[0] eq '-r' ? shift @ARGV : '';
my $filter = shift @ARGV;
my $input = do { local $/; <STDIN> };
my $data = decode_json(length($input // '') ? $input : '[]');

if ($filter =~ /^\. \+= \[ (\{.*\}) \]$/s) {
    push @{$data}, decode_json($1);
    print encode_json($data);
} elsif ($filter =~ /^del\(\.\[\] \| select\(\.name\s*==\s*"(.*)"\)\)$/) {
    my $name = $1;
    print encode_json([grep { $_->{name} ne $name } @{$data}]);
} elsif ($filter =~ /^\.\[\] \| select\(\.name\s*==\s*"(.*)"\)$/) {
    my $name = $1;
    print encode_json($_) . "\n" for grep { $_->{name} eq $name } @{$data};
} elsif ($filter eq '.path') {
    print $data->{path} . "\n";
} elsif ($filter eq '.[].name') {
    print $_->{name} . "\n" for @{$data};
} elsif ($filter eq '.') {
    print encode_json($data) . "\n";
} else {
    die "Unsupported test jq filter: $filter\n";
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

for format in dmg tar tar-gz tar-bz2 tar-xz zip xz pkg
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

rm -rf "${work_dir}" /tmp/cart.config
