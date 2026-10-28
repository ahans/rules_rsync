"""Analysis tests for rsync_deploy."""

load("@rules_testing//lib:analysis_test.bzl", "analysis_test", "test_suite")
load("@rules_testing//lib:truth.bzl", "matching", "subjects")
load("//rsync:defs.bzl", "RsyncDeployInfo")

_PACKAGE = "tests/analysis"

def _filter_lines(env, target):
    path = "%s/%s.rsync_filter" % (_PACKAGE, target.label.name)
    action = [a for a in target.actions if a.outputs.to_list()[0].short_path == path][0]
    return env.expect.that_collection(action.content.splitlines())

def _launcher(env, target):
    return env.expect.that_target(target).action_generating(
        "%s/%s" % (_PACKAGE, target.label.name),
    )

def _test_filter_selects_runfiles(name):
    analysis_test(name = name, impl = _test_filter_selects_runfiles_impl, target = ":app.deploy")

def _test_filter_selects_runfiles_impl(env, target):
    _filter_lines(env, target).contains_exactly([
        "+ /_repo_mapping",
        "+ /_main/",
        "+ /_main/tests/",
        "+ /_main/tests/analysis/",
        "+ /_main/tests/analysis/app",
        "+ /_main/tests/analysis/data.txt",
        "+ /_main/tests/analysis/odd\\[name]\\*.txt",
        # Rules for symlinks repeat their ancestors, which is harmless.
        "+ /_main/",
        "+ /_main/links/",
        "+ /_main/links/linked.txt",
        "+ /root_links/",
        "+ /root_links/root_linked.txt",
        "- *",
    ]).in_order()

def _test_deploy_info(name):
    analysis_test(name = name, impl = _test_deploy_info_impl, target = ":app.deploy")

def _test_deploy_info_impl(env, target):
    info = target[RsyncDeployInfo]
    env.expect.that_str(info.host).equals("attr-host")
    env.expect.that_str(info.dest).equals("rules_rsync/tests/analysis/app.deploy")
    env.expect.that_str(info.bin_name).equals("app")
    env.expect.that_str(info.bin_rlocation).equals("_main/tests/analysis/app")
    env.expect.that_str(info.label).equals("//tests/analysis:app")

def _test_build_flags_override_attrs(name):
    analysis_test(
        name = name,
        impl = _test_build_flags_override_attrs_impl,
        target = ":app.deploy",
        config_settings = {
            str(Label("//:dest")): "flag/dest",
            str(Label("//:host")): "flag-host",
        },
    )

def _test_build_flags_override_attrs_impl(env, target):
    substitutions = _launcher(env, target).substitutions()
    substitutions.get("%HOST%", factory = subjects.str).equals("'flag-host'")
    substitutions.get("%DEST%", factory = subjects.str).equals("'flag/dest'")

def _test_platform_transition(name):
    analysis_test(name = name, impl = _test_platform_transition_impl, target = ":selecting_app.deploy")

def _test_platform_transition_impl(env, target):
    lines = _filter_lines(env, target)
    lines.contains("+ /_main/tests/analysis/remote.txt")
    lines.not_contains("+ /_main/tests/analysis/local.txt")

def _test_non_executable_target_fails(name):
    analysis_test(
        name = name,
        impl = _test_non_executable_target_fails_impl,
        target = ":not_executable.deploy",
        expect_failure = True,
    )

def _test_non_executable_target_fails_impl(env, target):
    env.expect.that_target(target).failures().contains_predicate(
        matching.str_matches("*must be an executable*"),
    )

def deploy_test_suite(name):
    test_suite(
        name = name,
        tests = [
            _test_build_flags_override_attrs,
            _test_deploy_info,
            _test_filter_selects_runfiles,
            _test_non_executable_target_fails,
            _test_platform_transition,
        ],
    )
