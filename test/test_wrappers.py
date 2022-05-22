from pytest import mark
from sys import stdout, stderr

from subprocess import check_call


@mark.xfail
@mark.parametrize(
    "wrapper",
    [
        'symbiflow_generate_constraints',
        'symbiflow_pack',
        'symbiflow_place',
        'symbiflow_route',
        'symbiflow_synth',
        'symbiflow_write_bitstream',
        'symbiflow_write_fasm',
        'symbiflow_write_xml_rr_graph',
        'vpr_common',
        'symbiflow_analysis',
        'symbiflow_repack',
        'symbiflow_generate_bitstream',
        'symbiflow_generate_libfile',
        'ql_symbiflow'
    ]
)
def test_shell_wrapper(wrapper):
    print(f"\n::group::Test {wrapper}")
    stdout.flush()
    stderr.flush()
    try:
        check_call(f"{wrapper}")
    finally:
        print("\n::endgroup::")
