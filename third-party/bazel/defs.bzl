###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run @@//third-party:vendor
###############################################################################
"""
# `crates_repository` API

- [aliases](#aliases)
- [crate_deps](#crate_deps)
- [all_crate_deps](#all_crate_deps)
- [crate_repositories](#crate_repositories)

"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

###############################################################################
# MACROS API
###############################################################################

# An identifier that represent common dependencies (unconditional).
_COMMON_CONDITION = ""

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "workspace_member_package": {

            # Not all dependencies are supported for all platforms.
            # the condition key is the condition required to be true
            # on the host platform.
            "condition": {

                # An alias to a crate target.     # The label of the crate target the
                # Aliases are only crate names.   # package name refers to.
                "package_name":                   "@full//:label",
            }
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for workspace_deps_map in all_dependency_maps:
        for pkg_name, conditional_deps_map in workspace_deps_map.items():
            if pkg_name not in dependencies:
                non_frozen_map = dict()
                for key, values in conditional_deps_map.items():
                    non_frozen_map.update({key: dict(values.items())})
                dependencies.setdefault(pkg_name, non_frozen_map)
                continue

            for condition, deps_map in conditional_deps_map.items():
                # If the condition has not been recorded, do so and continue
                if condition not in dependencies[pkg_name]:
                    dependencies[pkg_name].setdefault(condition, dict(deps_map.items()))
                    continue

                # Alert on any miss-matched dependencies
                inconsistent_entries = []
                for crate_name, crate_label in deps_map.items():
                    existing = dependencies[pkg_name][condition].get(crate_name)
                    if existing and existing != crate_label:
                        inconsistent_entries.append((crate_name, existing, crate_label))
                    dependencies[pkg_name][condition].update({crate_name: crate_label})

    return dependencies

def crate_deps(deps, package_name = None):
    """Finds the fully qualified label of the requested crates for the package where this macro is called.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if not deps:
        return []

    if package_name == None:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _NORMAL_DEPENDENCIES,
        _NORMAL_DEV_DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _PROC_MACRO_DEV_DEPENDENCIES,
        _BUILD_DEPENDENCIES,
        _BUILD_PROC_MACRO_DEPENDENCIES,
    ]).pop(package_name, {})

    # Combine all conditional packages so we can easily index over a flat list
    # TODO: Perhaps this should actually return select statements and maintain
    # the conditionals of the dependencies
    flat_deps = {}
    for deps_set in dependencies.values():
        for crate_name, crate_label in deps_set.items():
            flat_deps.update({crate_name: crate_label})

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in flat_deps:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(flat_deps[crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies,
        ))

    return crate_targets

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_NORMAL_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_PROC_MACRO_DEV_DEPENDENCIES)
    if build:
        all_dependency_maps.append(_BUILD_DEPENDENCIES)
    if build_proc_macro:
        all_dependency_maps.append(_BUILD_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps).pop(package_name, None)

    if not dependencies:
        if dependencies == None:
            fail("Tried to get all_crate_deps for package " + package_name + " but that package had no Cargo.toml file")
        else:
            return []

    crate_deps = list(dependencies.pop(_COMMON_CONDITION, {}).values())
    for condition, deps in dependencies.items():
        crate_deps += selects.with_or({
            tuple(_CONDITIONS[condition]): deps.values(),
            "//conditions:default": [],
        })

    return crate_deps

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Produces a map of Crate alias names to their original label

    If no dependency kinds are specified, `normal` and `proc_macro` are used by default.
    Setting any one flag will otherwise determine the contents of the returned dict.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        dict: The aliases of all associated packages
    """
    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_aliases_maps = []
    if normal:
        all_aliases_maps.append(_NORMAL_ALIASES)
    if normal_dev:
        all_aliases_maps.append(_NORMAL_DEV_ALIASES)
    if proc_macro:
        all_aliases_maps.append(_PROC_MACRO_ALIASES)
    if proc_macro_dev:
        all_aliases_maps.append(_PROC_MACRO_DEV_ALIASES)
    if build:
        all_aliases_maps.append(_BUILD_ALIASES)
    if build_proc_macro:
        all_aliases_maps.append(_BUILD_PROC_MACRO_ALIASES)

    # Default to always using normal aliases
    if not all_aliases_maps:
        all_aliases_maps.append(_NORMAL_ALIASES)
        all_aliases_maps.append(_PROC_MACRO_ALIASES)

    aliases = _flatten_dependency_maps(all_aliases_maps).pop(package_name, None)

    if not aliases:
        return dict()

    common_items = aliases.pop(_COMMON_CONDITION, {}).items()

    # If there are only common items in the dictionary, immediately return them
    if not len(aliases.keys()) == 1:
        return dict(common_items)

    # Build a single select statement where each conditional has accounted for the
    # common set of aliases.
    crate_aliases = {"//conditions:default": dict(common_items)}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        for triple in condition_triples:
            if triple in crate_aliases:
                crate_aliases[triple].update(deps)
            else:
                crate_aliases.update({triple: dict(deps.items() + common_items)})

    return select(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "third-party": {
        _COMMON_CONDITION: {
            "cc": Label("@vendor__cc-1.2.3//:cc"),
            "clap": Label("@vendor__clap-4.5.23//:clap"),
            "codespan-reporting": Label("@vendor__codespan-reporting-0.11.1//:codespan_reporting"),
            "foldhash": Label("@vendor__foldhash-0.1.3//:foldhash"),
            "proc-macro2": Label("@vendor__proc-macro2-1.0.92//:proc_macro2"),
            "quote": Label("@vendor__quote-1.0.37//:quote"),
            "scratch": Label("@vendor__scratch-1.0.7//:scratch"),
            "syn": Label("@vendor__syn-2.0.90//:syn"),
        },
    },
}

_NORMAL_ALIASES = {
    "third-party": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "third-party": {
    },
}

_NORMAL_DEV_ALIASES = {
    "third-party": {
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "third-party": {
        _COMMON_CONDITION: {
            "rustversion": Label("@vendor__rustversion-1.0.18//:rustversion"),
        },
    },
}

_PROC_MACRO_ALIASES = {
    "third-party": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "third-party": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "third-party": {
    },
}

_BUILD_DEPENDENCIES = {
    "third-party": {
    },
}

_BUILD_ALIASES = {
    "third-party": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "third-party": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "third-party": {
    },
}

_CONDITIONS = {
    "aarch64-apple-darwin": ["@rules_rust//rust/platform:aarch64-apple-darwin"],
    "aarch64-apple-ios": ["@rules_rust//rust/platform:aarch64-apple-ios"],
    "aarch64-apple-ios-sim": ["@rules_rust//rust/platform:aarch64-apple-ios-sim"],
    "aarch64-linux-android": ["@rules_rust//rust/platform:aarch64-linux-android"],
    "aarch64-pc-windows-gnullvm": [],
    "aarch64-pc-windows-msvc": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc"],
    "aarch64-unknown-fuchsia": ["@rules_rust//rust/platform:aarch64-unknown-fuchsia"],
    "aarch64-unknown-linux-gnu": ["@rules_rust//rust/platform:aarch64-unknown-linux-gnu"],
    "aarch64-unknown-nixos-gnu": ["@rules_rust//rust/platform:aarch64-unknown-nixos-gnu"],
    "aarch64-unknown-nto-qnx710": ["@rules_rust//rust/platform:aarch64-unknown-nto-qnx710"],
    "arm-unknown-linux-gnueabi": ["@rules_rust//rust/platform:arm-unknown-linux-gnueabi"],
    "armv7-linux-androideabi": ["@rules_rust//rust/platform:armv7-linux-androideabi"],
    "armv7-unknown-linux-gnueabi": ["@rules_rust//rust/platform:armv7-unknown-linux-gnueabi"],
    "cfg(all(any(target_arch = \"x86_64\", target_arch = \"arm64ec\"), target_env = \"msvc\", not(windows_raw_dylib)))": ["@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "cfg(all(target_arch = \"aarch64\", target_env = \"msvc\", not(windows_raw_dylib)))": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc"],
    "cfg(all(target_arch = \"x86\", target_env = \"gnu\", not(target_abi = \"llvm\"), not(windows_raw_dylib)))": ["@rules_rust//rust/platform:i686-unknown-linux-gnu"],
    "cfg(all(target_arch = \"x86\", target_env = \"msvc\", not(windows_raw_dylib)))": ["@rules_rust//rust/platform:i686-pc-windows-msvc"],
    "cfg(all(target_arch = \"x86_64\", target_env = \"gnu\", not(target_abi = \"llvm\"), not(windows_raw_dylib)))": ["@rules_rust//rust/platform:x86_64-unknown-linux-gnu", "@rules_rust//rust/platform:x86_64-unknown-nixos-gnu"],
    "cfg(windows)": ["@rules_rust//rust/platform:aarch64-pc-windows-msvc", "@rules_rust//rust/platform:i686-pc-windows-msvc", "@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "i686-apple-darwin": ["@rules_rust//rust/platform:i686-apple-darwin"],
    "i686-linux-android": ["@rules_rust//rust/platform:i686-linux-android"],
    "i686-pc-windows-gnullvm": [],
    "i686-pc-windows-msvc": ["@rules_rust//rust/platform:i686-pc-windows-msvc"],
    "i686-unknown-freebsd": ["@rules_rust//rust/platform:i686-unknown-freebsd"],
    "i686-unknown-linux-gnu": ["@rules_rust//rust/platform:i686-unknown-linux-gnu"],
    "powerpc-unknown-linux-gnu": ["@rules_rust//rust/platform:powerpc-unknown-linux-gnu"],
    "riscv32imc-unknown-none-elf": ["@rules_rust//rust/platform:riscv32imc-unknown-none-elf"],
    "riscv64gc-unknown-none-elf": ["@rules_rust//rust/platform:riscv64gc-unknown-none-elf"],
    "s390x-unknown-linux-gnu": ["@rules_rust//rust/platform:s390x-unknown-linux-gnu"],
    "thumbv7em-none-eabi": ["@rules_rust//rust/platform:thumbv7em-none-eabi"],
    "thumbv8m.main-none-eabi": ["@rules_rust//rust/platform:thumbv8m.main-none-eabi"],
    "wasm32-unknown-unknown": ["@rules_rust//rust/platform:wasm32-unknown-unknown"],
    "wasm32-wasi": ["@rules_rust//rust/platform:wasm32-wasi"],
    "wasm32-wasip1": ["@rules_rust//rust/platform:wasm32-wasip1"],
    "x86_64-apple-darwin": ["@rules_rust//rust/platform:x86_64-apple-darwin"],
    "x86_64-apple-ios": ["@rules_rust//rust/platform:x86_64-apple-ios"],
    "x86_64-linux-android": ["@rules_rust//rust/platform:x86_64-linux-android"],
    "x86_64-pc-windows-gnullvm": [],
    "x86_64-pc-windows-msvc": ["@rules_rust//rust/platform:x86_64-pc-windows-msvc"],
    "x86_64-unknown-freebsd": ["@rules_rust//rust/platform:x86_64-unknown-freebsd"],
    "x86_64-unknown-fuchsia": ["@rules_rust//rust/platform:x86_64-unknown-fuchsia"],
    "x86_64-unknown-linux-gnu": ["@rules_rust//rust/platform:x86_64-unknown-linux-gnu"],
    "x86_64-unknown-nixos-gnu": ["@rules_rust//rust/platform:x86_64-unknown-nixos-gnu"],
    "x86_64-unknown-none": ["@rules_rust//rust/platform:x86_64-unknown-none"],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates.

    Returns:
      A list of repos visible to the module through the module extension.
    """
    maybe(
        http_archive,
        name = "vendor__anstyle-1.0.10",
        sha256 = "55cc3b69f167a1ef2e161439aa98aed94e6028e5f9a59be9a6ffb47aef1651f9",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/anstyle/1.0.10/download"],
        strip_prefix = "anstyle-1.0.10",
        build_file = Label("//third-party/bazel:BUILD.anstyle-1.0.10.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__cc-1.2.3",
        sha256 = "27f657647bcff5394bf56c7317665bbf790a137a50eaaa5c6bfbb9e27a518f2d",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/cc/1.2.3/download"],
        strip_prefix = "cc-1.2.3",
        build_file = Label("//third-party/bazel:BUILD.cc-1.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__clap-4.5.23",
        sha256 = "3135e7ec2ef7b10c6ed8950f0f792ed96ee093fa088608f1c76e569722700c84",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap/4.5.23/download"],
        strip_prefix = "clap-4.5.23",
        build_file = Label("//third-party/bazel:BUILD.clap-4.5.23.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__clap_builder-4.5.23",
        sha256 = "30582fc632330df2bd26877bde0c1f4470d57c582bbc070376afcd04d8cb4838",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap_builder/4.5.23/download"],
        strip_prefix = "clap_builder-4.5.23",
        build_file = Label("//third-party/bazel:BUILD.clap_builder-4.5.23.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__clap_lex-0.7.4",
        sha256 = "f46ad14479a25103f283c0f10005961cf086d8dc42205bb44c46ac563475dca6",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/clap_lex/0.7.4/download"],
        strip_prefix = "clap_lex-0.7.4",
        build_file = Label("//third-party/bazel:BUILD.clap_lex-0.7.4.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__codespan-reporting-0.11.1",
        sha256 = "3538270d33cc669650c4b093848450d380def10c331d38c768e34cac80576e6e",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/codespan-reporting/0.11.1/download"],
        strip_prefix = "codespan-reporting-0.11.1",
        build_file = Label("//third-party/bazel:BUILD.codespan-reporting-0.11.1.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__foldhash-0.1.3",
        sha256 = "f81ec6369c545a7d40e4589b5597581fa1c441fe1cce96dd1de43159910a36a2",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/foldhash/0.1.3/download"],
        strip_prefix = "foldhash-0.1.3",
        build_file = Label("//third-party/bazel:BUILD.foldhash-0.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__proc-macro2-1.0.92",
        sha256 = "37d3544b3f2748c54e147655edb5025752e2303145b5aefb3c3ea2c78b973bb0",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/proc-macro2/1.0.92/download"],
        strip_prefix = "proc-macro2-1.0.92",
        build_file = Label("//third-party/bazel:BUILD.proc-macro2-1.0.92.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__quote-1.0.37",
        sha256 = "b5b9d34b8991d19d98081b46eacdd8eb58c6f2b201139f7c5f643cc155a633af",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/quote/1.0.37/download"],
        strip_prefix = "quote-1.0.37",
        build_file = Label("//third-party/bazel:BUILD.quote-1.0.37.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__rustversion-1.0.18",
        sha256 = "0e819f2bc632f285be6d7cd36e25940d45b2391dd6d9b939e79de557f7014248",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/rustversion/1.0.18/download"],
        strip_prefix = "rustversion-1.0.18",
        build_file = Label("//third-party/bazel:BUILD.rustversion-1.0.18.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__scratch-1.0.7",
        sha256 = "a3cf7c11c38cb994f3d40e8a8cde3bbd1f72a435e4c49e85d6553d8312306152",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/scratch/1.0.7/download"],
        strip_prefix = "scratch-1.0.7",
        build_file = Label("//third-party/bazel:BUILD.scratch-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__shlex-1.3.0",
        sha256 = "0fda2ff0d084019ba4d7c6f371c95d8fd75ce3524c3cb8fb653a3023f6323e64",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/shlex/1.3.0/download"],
        strip_prefix = "shlex-1.3.0",
        build_file = Label("//third-party/bazel:BUILD.shlex-1.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__syn-2.0.90",
        sha256 = "919d3b74a5dd0ccd15aeb8f93e7006bd9e14c295087c9896a110f490752bcf31",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/syn/2.0.90/download"],
        strip_prefix = "syn-2.0.90",
        build_file = Label("//third-party/bazel:BUILD.syn-2.0.90.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__termcolor-1.4.1",
        sha256 = "06794f8f6c5c898b3275aebefa6b8a1cb24cd2c6c79397ab15774837a0bc5755",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/termcolor/1.4.1/download"],
        strip_prefix = "termcolor-1.4.1",
        build_file = Label("//third-party/bazel:BUILD.termcolor-1.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__unicode-ident-1.0.14",
        sha256 = "adb9e6ca4f869e1180728b7950e35922a7fc6397f7b641499e8f3ef06e50dc83",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-ident/1.0.14/download"],
        strip_prefix = "unicode-ident-1.0.14",
        build_file = Label("//third-party/bazel:BUILD.unicode-ident-1.0.14.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__unicode-width-0.1.14",
        sha256 = "7dd6e30e90baa6f72411720665d41d89b9a3d039dc45b8faea1ddd07f617f6af",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/unicode-width/0.1.14/download"],
        strip_prefix = "unicode-width-0.1.14",
        build_file = Label("//third-party/bazel:BUILD.unicode-width-0.1.14.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__winapi-util-0.1.9",
        sha256 = "cf221c93e13a30d793f7645a0e7762c55d169dbb0a49671918a2319d289b10bb",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/winapi-util/0.1.9/download"],
        strip_prefix = "winapi-util-0.1.9",
        build_file = Label("//third-party/bazel:BUILD.winapi-util-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows-sys-0.59.0",
        sha256 = "1e38bc4d79ed67fd075bcc251a1c39b32a1776bbe92e5bef1f0bf1f8c531853b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows-sys/0.59.0/download"],
        strip_prefix = "windows-sys-0.59.0",
        build_file = Label("//third-party/bazel:BUILD.windows-sys-0.59.0.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows-targets-0.52.6",
        sha256 = "9b724f72796e036ab90c1021d4780d4d3d648aca59e491e6b98e725b84e99973",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows-targets/0.52.6/download"],
        strip_prefix = "windows-targets-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows-targets-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_aarch64_gnullvm-0.52.6",
        sha256 = "32a4622180e7a0ec044bb555404c800bc9fd9ec262ec147edd5989ccd0c02cd3",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_aarch64_gnullvm/0.52.6/download"],
        strip_prefix = "windows_aarch64_gnullvm-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_aarch64_gnullvm-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_aarch64_msvc-0.52.6",
        sha256 = "09ec2a7bb152e2252b53fa7803150007879548bc709c039df7627cabbd05d469",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_aarch64_msvc/0.52.6/download"],
        strip_prefix = "windows_aarch64_msvc-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_aarch64_msvc-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_i686_gnu-0.52.6",
        sha256 = "8e9b5ad5ab802e97eb8e295ac6720e509ee4c243f69d781394014ebfe8bbfa0b",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_i686_gnu/0.52.6/download"],
        strip_prefix = "windows_i686_gnu-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_i686_gnu-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_i686_gnullvm-0.52.6",
        sha256 = "0eee52d38c090b3caa76c563b86c3a4bd71ef1a819287c19d586d7334ae8ed66",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_i686_gnullvm/0.52.6/download"],
        strip_prefix = "windows_i686_gnullvm-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_i686_gnullvm-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_i686_msvc-0.52.6",
        sha256 = "240948bc05c5e7c6dabba28bf89d89ffce3e303022809e73deaefe4f6ec56c66",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_i686_msvc/0.52.6/download"],
        strip_prefix = "windows_i686_msvc-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_i686_msvc-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_x86_64_gnu-0.52.6",
        sha256 = "147a5c80aabfbf0c7d901cb5895d1de30ef2907eb21fbbab29ca94c5b08b1a78",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_x86_64_gnu/0.52.6/download"],
        strip_prefix = "windows_x86_64_gnu-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_x86_64_gnu-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_x86_64_gnullvm-0.52.6",
        sha256 = "24d5b23dc417412679681396f2b49f3de8c1473deb516bd34410872eff51ed0d",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_x86_64_gnullvm/0.52.6/download"],
        strip_prefix = "windows_x86_64_gnullvm-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_x86_64_gnullvm-0.52.6.bazel"),
    )

    maybe(
        http_archive,
        name = "vendor__windows_x86_64_msvc-0.52.6",
        sha256 = "589f6da84c646204747d1270a2a5661ea66ed1cced2631d546fdfb155959f9ec",
        type = "tar.gz",
        urls = ["https://static.crates.io/crates/windows_x86_64_msvc/0.52.6/download"],
        strip_prefix = "windows_x86_64_msvc-0.52.6",
        build_file = Label("//third-party/bazel:BUILD.windows_x86_64_msvc-0.52.6.bazel"),
    )

    return [
        struct(repo = "vendor__cc-1.2.3", is_dev_dep = False),
        struct(repo = "vendor__clap-4.5.23", is_dev_dep = False),
        struct(repo = "vendor__codespan-reporting-0.11.1", is_dev_dep = False),
        struct(repo = "vendor__foldhash-0.1.3", is_dev_dep = False),
        struct(repo = "vendor__proc-macro2-1.0.92", is_dev_dep = False),
        struct(repo = "vendor__quote-1.0.37", is_dev_dep = False),
        struct(repo = "vendor__rustversion-1.0.18", is_dev_dep = False),
        struct(repo = "vendor__scratch-1.0.7", is_dev_dep = False),
        struct(repo = "vendor__syn-2.0.90", is_dev_dep = False),
    ]
