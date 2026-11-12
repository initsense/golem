#!/bin/sh
set -e

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dir=$script_dir
root=
while [ "$dir" != "/" ]; do
	if [ -f "$dir/.gitmodules" ] && grep -q 'vendor/golem' "$dir/.gitmodules"; then
		root=$dir
		break
	fi
	dir=$(dirname "$dir")
done

if [ -z "$root" ]; then
	echo "update.sh: no game root with a vendor/golem submodule was found." >&2
	exit 1
fi

cd "$root"

if [ ! -d vendor/golem/.git ] && [ ! -f vendor/golem/.git ]; then
	echo "update.sh: vendor/golem is not a submodule checkout yet." >&2
	exit 1
fi

pin=0
if [ "${1:-}" = "--pin" ]; then
	pin=1
fi

if [ "$pin" -eq 1 ]; then
	git submodule update vendor/golem
else
	git submodule update --remote vendor/golem
fi

git -C vendor/golem sparse-checkout set addons/golem

if [ ! -f vendor/.gdignore ]; then
	mkdir -p vendor
	: > vendor/.gdignore
fi

ln -sfn ../vendor/golem/addons/golem addons/golem
mkdir -p .cursor/rules
ln -sfn ../../addons/golem/.cursor/rules/use-golem.mdc .cursor/rules/use-golem.mdc

echo "Golem is at $(git -C vendor/golem rev-parse --short HEAD)."
echo "Commit the vendor/golem pointer in this game when you want other clones to record it."
