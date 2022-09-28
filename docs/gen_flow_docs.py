# XXX: Hack to make f4pga think that we are in an environment set-up for eos-s3.
# eos-s3 has been chosen because it does not require prjxray-config which is used when
# configuring variables available for xc7.
import os
os.environ["FPGA_FAM"] = "eos-s3"

import yaml
from f4pga.flows.commands import setup_resolution_env
import jinja2
from f4pga.flows.common import (
    scan_modules as f4pga_scan_modules,
    ROOT as f4pga_ROOT,
    F4PGAException,
)
from f4pga.flows.flow_config import FlowDefinition as f4pga_FlowDefinition
from f4pga.flows.commands import setup_resolution_env as f4pga_setup_resolution_env
from f4pga.flows.inspector import get_stages_info_dict as f4pga_get_stages_info_dict
from argparse import ArgumentParser
from pathlib import Path
import sys

class FailedFlowGenException(Exception):
    platform: str

    def __init__(self, platform: str):
        self.platform = platform

class Inspector:
    part_db: dict
    platforms: dict

    def __init__(self):
        with open(f4pga_ROOT / "part_db.yml", "r") as f:
            self.part_db = yaml.safe_load(f.read())
        with (f4pga_ROOT / "platforms.yml").open("r") as f:
            self.platforms = yaml.safe_load(f.read())
        
    def get_platforms(self):
        return self.part_db.keys()
    
    def get_platform_flow_info(self, platform: str):
        platform_def = self.platforms.get(platform)
        if platform_def is None:
            raise F4PGAException(
                message=f"Flow definition for platform <{platform}> cannot be found!"
            )
        
        r_env = f4pga_setup_resolution_env()
        
        # XXX: We don't care for the exact part name, but it might be required to initilize
        # stages. There's an assumption being made here, that it won't affect I/O.
        part_name = self.part_db[platform][0]
        r_env.add_values({"part_name": part_name.lower()})

        return f4pga_get_stages_info_dict(
            f4pga_FlowDefinition(self.platforms[platform], r_env)
        )

class FlowDocGenerator:
    inspector: Inspector
    template: jinja2.Template

    def __init__(self, inspector: Inspector, template_path: str = "flow.rst.jinja2"):
        self.inspector = inspector

        with open(template_path, "r") as f:
            template_src = f.read()
        
        self.template = jinja2.Template(template_src)
    
    def get_user_deps(self, io):
        all_takes = set()
        all_produces = set()
        for stage_io in io.values():
            all_takes.update(stage_io["takes"].keys())
            all_produces.update(stage_io["produces"].keys())
        
        non_producible_takes = all_takes.difference(all_produces)

        user_deps = dict((take, "n/a") for take in non_producible_takes)
        user_dep_r_users = dict((take, []) for take in non_producible_takes)

        for stage, stage_io in io.items():
            for take, take_spec in stage_io["takes"].items():
                if take not in user_deps.keys():
                    continue

                q = take_spec["qualifier"]
                if q == "req":
                    if user_deps[take] == "n/a":
                        user_deps[take] = "yes"
                    elif user_deps[take] == "yes":
                        user_deps[take] = "yes"
                    elif user_deps[take] == "no":
                        user_deps[take] = f"required by {stage}"
                    elif "required by" in user_deps[take]:
                        user_deps[take] += f", {stage}"
                    user_dep_r_users[take].append(stage)
                if q == "maybe":
                    if user_deps[take] == "yes":
                        user_deps[take] = f"required by {','.join(user_dep_r_users[take])}"
                    if "required by" not in user_deps[take]:
                        user_deps[take] = "no"

        return user_deps
    
    def get_targets(self, io):
        all_produces = {}
        for stage_io in io.values():
            all_produces.update(stage_io["produces"].items())
        
        for target_spec in all_produces.values():
            if target_spec.get("meta") is None:
                target_spec["meta"] = "*(No description)*"
            else:
                target_spec["meta"] = target_spec["meta"].replace("\n", " ") 
        
        return all_produces
    
    def generate_doc_for_platform(self, platform_name: str) -> str:
        try:
            io = self.inspector.get_platform_flow_info(platform_name)
        except:
            raise FailedFlowGenException(platform_name)
            
        stages = list(io.keys())
        sup_chips = self.inspector.part_db[platform_name]

        targets = self.get_targets(io)
        user_deps = self.get_user_deps(io)

        return self.template.render(
            platform_name=platform_name,
            stages=stages,
            sup_chips=sup_chips,
            user_deps=user_deps,
            targets=targets,
            # XXX: Handling dumb ASCII-art requirements for tables.
            inputs_len_0=max([len(name) for name in user_deps.keys()] + [len("Name")]),
            inputs_len_1=max([len(v) for v in user_deps.values()] + [len("Is required to execute entire flow?")]),
            targets_len_0=max([len(name) for name in targets.keys()] + [len("Name")]),
            targets_len_2=max([len(v["meta"]) for v in targets.values()] + [len("Description")])
        )


def main():
    argparser = ArgumentParser()
    argparser.add_argument("output_dir")
    args = argparser.parse_args()

    output_dir = Path(args.output_dir)

    f4pga_scan_modules()

    inspector = Inspector()
    doc_gen = FlowDocGenerator(inspector)
    for platform_name in inspector.get_platforms():
        try:
            doc = doc_gen.generate_doc_for_platform(platform_name)
        except FailedFlowGenException as e:
            print(
                f"WARNING: Failed to create a flow for platform <{e.platform}>",
                file=sys.stderr
            )
            continue
        with open(output_dir / f"{platform_name}.rst", "w") as f:
            f.write(doc)


if __name__ == "__main__":
    main()