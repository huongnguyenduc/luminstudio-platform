def _flutter_validation_test_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name)
    runner_path = "%s/%s" % (ctx.workspace_name, ctx.file.runner.short_path)
    content = """#!/usr/bin/env bash
set -euo pipefail

runfiles_dir="${{RUNFILES_DIR:-$0.runfiles}}"
runner="$runfiles_dir/{runner_path}"

if [[ ! -x "$runner" ]]; then
  echo "Flutter validation runner not found: $runner" >&2
  exit 1
fi

exec "$runner" "$@"
""".format(runner_path = runner_path)

    ctx.actions.write(
        output = executable,
        content = content,
        is_executable = True,
    )

    return [DefaultInfo(
        executable = executable,
        runfiles = ctx.runfiles(files = ctx.files.data + [ctx.file.runner]),
    )]

flutter_validation_test = rule(
    implementation = _flutter_validation_test_impl,
    attrs = {
        "data": attr.label_list(allow_files = True),
        "runner": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
    },
    test = True,
)
