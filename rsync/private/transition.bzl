"""Transition that builds the deployed target for the remote host's platform."""

_PLATFORMS = "//command_line_option:platforms"

def _platform_transition_impl(settings, attr):
    if not attr.platform:
        return {_PLATFORMS: settings[_PLATFORMS]}
    return {_PLATFORMS: [str(attr.platform)]}

platform_transition = transition(
    implementation = _platform_transition_impl,
    inputs = [_PLATFORMS],
    outputs = [_PLATFORMS],
)
