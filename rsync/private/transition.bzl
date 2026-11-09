"""Platform transition to build deploy targets for remote host platform."""

_PLATFORMS = "//command_line_option:platforms"

def _impl(settings, attr):
    if not attr.platform:
        return {_PLATFORMS: settings[_PLATFORMS]}  # keep as-is
    return {_PLATFORMS: [str(attr.platform)]}

platform_transition = transition(
    implementation = _impl,
    inputs = [_PLATFORMS],
    outputs = [_PLATFORMS],
)
