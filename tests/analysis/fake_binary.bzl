"""An executable rule without toolchains, with full control over its runfiles."""

def _fake_binary_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(executable, "#!/bin/sh\n", is_executable = True)
    runfiles = ctx.runfiles(
        files = [executable] + ctx.files.data,
        symlinks = {"links/" + f.basename: f for f in ctx.files.symlinks},
        root_symlinks = {"root_links/" + f.basename: f for f in ctx.files.root_symlinks},
    )
    return [DefaultInfo(executable = executable, runfiles = runfiles)]

fake_binary = rule(
    implementation = _fake_binary_impl,
    executable = True,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "root_symlinks": attr.label_list(allow_files = True),
        "symlinks": attr.label_list(allow_files = True),
    },
)
