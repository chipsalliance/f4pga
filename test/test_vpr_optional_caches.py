import importlib.util
from pathlib import Path
import sys
from types import ModuleType
import unittest
from unittest.mock import Mock


common = ModuleType("f4pga.flows.common")
common.sub = Mock()
common.options_dict_to_list = lambda options: [
    item
    for key, value in options.items()
    for item in (f"--{key}", str(value))
]
sys.modules[common.__name__] = common
module_path = Path(__file__).parents[1] / "f4pga/flows/tools/vpr.py"
spec = importlib.util.spec_from_file_location("xc6s_test_vpr", module_path)
vpr_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vpr_module)


class VprOptionalCachesTest(unittest.TestCase):
    def make_args(self, lookahead=None, place_delay=None):
        return vpr_module.VprArgs(
            share="/share",
            eblif="design.eblif",
            arch_def="arch.xml",
            lookahead=lookahead,
            rr_graph="rr_graph.bin",
            place_delay=place_delay,
            device_name="xc6slx9",
            vpr_options={"timing_analysis": "off"},
        )

    def test_omits_unavailable_cache_arguments(self):
        run = Mock()
        vpr_module.common_sub = run
        vpr_module.vpr("pack", self.make_args())
        args = run.call_args.args
        self.assertNotIn("--read_router_lookahead", args)
        self.assertNotIn("--read_placement_delay_lookup", args)
        self.assertIn("--timing_analysis", args)
        self.assertIn("off", args)

    def test_preserves_existing_cached_flow(self):
        run = Mock()
        vpr_module.common_sub = run
        vpr_module.vpr("route", self.make_args("lookahead.bin", "place_delay.bin"))
        args = run.call_args.args
        self.assertEqual(args[args.index("--read_router_lookahead") + 1], "lookahead.bin")
        self.assertEqual(
            args[args.index("--read_placement_delay_lookup") + 1], "place_delay.bin"
        )


if __name__ == "__main__":
    unittest.main()
