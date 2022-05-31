from os import environ
from pytest import mark
from sys import stdout, stderr

from subprocess import check_call


wrappers = [
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

@mark.xfail
@mark.parametrize(
    "wrapper",
    wrappers
)
def test_shell_wrapper(wrapper):
    print(f"\n::group::Test {wrapper}")
    stdout.flush()
    stderr.flush()
    try:
        check_call(f"{wrapper}")
    finally:
        print("\n::endgroup::")

@mark.xfail
@mark.parametrize(
    "wrapper",
    wrappers
)
def test_shell_wrapper_without_F4PGA_INSTALL_DIR(wrapper):
    test_environ = environ.copy()
    del test_environ['F4PGA_INSTALL_DIR']

    print(f"\n::group::Test {wrapper}")
    stdout.flush()
    stderr.flush()
    try:
        check_call(f"{wrapper}", env=test_environ)
    finally:
        print("\n::endgroup::")
