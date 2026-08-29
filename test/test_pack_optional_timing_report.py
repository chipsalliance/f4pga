import importlib.util
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import Mock


def load_pack_module():
    module_names = (
        "f4pga.flows.common",
        "f4pga.flows.module",
        "f4pga.flows.tools.vpr",
    )
    saved = {name: sys.modules.get(name) for name in module_names}

    common = ModuleType(module_names[0])
    common.noisy_warnings = Mock()
    module_api = ModuleType(module_names[1])
    module_api.Module = object
    module_api.ModuleContext = object
    vpr_api = ModuleType(module_names[2])
    vpr_api.vpr_specific_values = []
    vpr_api.vpr = Mock()
    vpr_api.VprArgs = lambda **kwargs: kwargs

    sys.modules[common.__name__] = common
    sys.modules[module_api.__name__] = module_api
    sys.modules[vpr_api.__name__] = vpr_api
    try:
        module_path = Path(__file__).parents[1] / "f4pga/flows/modules/pack.py"
        spec = importlib.util.spec_from_file_location("xc6s_test_pack", module_path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    finally:
        for name, previous in saved.items():
            if previous is None:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = previous


pack_module = load_pack_module()


class PackOptionalTimingReportTest(unittest.TestCase):
    def make_context(self, build_dir, timing_rpt=None):
        build_dir = Path(build_dir)
        return SimpleNamespace(
            share="/share",
            takes=SimpleNamespace(
                eblif=str(build_dir / "design.eblif"),
                sdc=None,
            ),
            outputs=SimpleNamespace(
                net=str(build_dir / "design.net"),
                pack_log=None,
                timing_rpt=timing_rpt,
                util_rpt=str(build_dir / pack_module.DEFAULT_UTIL_RPT),
            ),
            values=SimpleNamespace(
                device="xc6slx9",
                arch_def="arch.xml",
                rr_graph_lookahead_bin=None,
                rr_graph_real_bin="rr_graph.bin",
                vpr_place_delay=None,
                vpr_grid_layout_name="xc6slx9",
                vpr_options={"timing_analysis": "off"},
            ),
        )

    def prepare_vpr_outputs(self, build_dir):
        root = Path(build_dir)
        (root / "vpr_stdout.log").write_text("VPR succeeded\n", encoding="utf-8")
        (root / pack_module.DEFAULT_UTIL_RPT).write_text(
            "utilization\n", encoding="utf-8"
        )

    def test_timing_report_is_on_demand(self):
        module = pack_module.PackModule(None)
        self.assertIn("timing_rpt!", module.produces)
        with TemporaryDirectory() as temp_dir:
            self.prepare_vpr_outputs(temp_dir)
            list(module.execute(self.make_context(temp_dir)))

    def test_missing_requested_timing_report_fails(self):
        module = pack_module.PackModule(None)
        with TemporaryDirectory() as temp_dir:
            self.prepare_vpr_outputs(temp_dir)
            ctx = self.make_context(temp_dir, str(Path(temp_dir) / "timing.rpt"))
            with self.assertRaisesRegex(FileNotFoundError, "requested timing report"):
                list(module.execute(ctx))


if __name__ == "__main__":
    unittest.main()
