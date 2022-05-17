from pathlib import Path
from copy import copy
from os import listdir as os_listdir
from json import dump as json_dump, load as json_load

from f4pga.common import ResolutionEnv, deep
from f4pga.stage import Stage


def open_flow_cfg(path: str) -> dict:
    with Path(path).open('r') as rfptr:
        return json_load(rfptr)

def _get_ovs_raw(
    dict_name: str,
    flow_cfg,
    platform: 'str | None',
    stage: 'str | None'
):
    vals = flow_cfg.get(dict_name)
    if vals is None:
        vals = {}
    if platform is not None:
        platform_vals= flow_cfg[platform].get(dict_name)
        if platform_vals is not None:
            vals.update(platform_vals)
        if stage is not None:
            stage_deps = flow_cfg[platform][stage].get(dict_name)
            if stage_deps is not None:
                vals.update(stage_deps)

    return vals

def verify_platform_name(platform: str, mypath: str):
    for plat_def_filename in os_listdir(str(Path(mypath) / 'platforms')):
        platform_name = str(Path(plat_def_filename).stem)
        if platform == platform_name:
            return True
    return False


def verify_stage(platform: str, stage: str, mypath: str):
    # TODO: Verify stage
    return True


def _is_kword(w: str):
    kwords = {
        'dependencies',
        'values',
        'default_platform',
        'default_target'
    }
    return w in kwords


class FlowDefinition:
    stages: 'dict[str, Stage]' # stage name -> module path mapping
    r_env: ResolutionEnv

    def __init__(self, flow_def: dict, r_env: ResolutionEnv):
        self.flow_def = flow_def
        self.r_env = r_env
        self.stages = {}

        global_vals = flow_def.get('values')
        if global_vals is not None:
            self.r_env.add_values(global_vals)

        stages_d = flow_def['stages']
        modopts_d = flow_def.get('stage_options')
        if modopts_d is None:
            modopts_d = {}

        for stage_name, modstr in stages_d.items():
            opts = modopts_d.get(stage_name)
            self.stages[stage_name] = Stage(stage_name, modstr, opts)

    def stage_names(self):
        return self.stages.keys()

    def get_stage_r_env(self, stage_name: 'str') -> ResolutionEnv:
        stage = self.stages[stage_name]
        r_env = copy(self.r_env)
        r_env.add_values(stage.value_overrides)
        return r_env


class ProjectFlowConfig:
    flow_cfg: dict
    path: str

    def __init__(self, path: str):
        self.flow_cfg = {}
        self.path = copy(path)

    def platforms(self):
        for platform, _ in self.flow_cfg.items():
            if not _is_kword(platform):
                yield platform

    def get_default_platform(self) -> 'str | None':
        return self.flow_cfg.get('default_platform')

    def get_default_target(self, platform: str) -> 'str | None':
        return self.flow_cfg[platform].get('default_target')

    def get_stage_r_env(self, platform: str, stage: str) -> ResolutionEnv:
        r_env = self._cache_platform_r_env(platform)

        stage_cfg = self.flow_cfg[platform][stage]
        stage_values = stage_cfg.get('values')
        if stage_values:
            r_env.add_values(stage_values)

        return r_env

    def get_dependencies_raw(self, platform: 'str | None' = None):
        """
        Get dependencies without value resolution applied.
        """
        return _get_ovs_raw('dependencies', self.flow_cfg, platform, None)

    def get_values_raw(
        self,
        platform: 'str | None' = None,
        stage: 'str | None' = None
    ):
        """
        Get values without value resolution applied.
        """
        return _get_ovs_raw('values', self.flow_cfg, platform, stage)

    def get_stage_value_overrides(self, platform: str, stage: str):
        stage_cfg = self.flow_cfg[platform].get(stage)
        if stage_cfg is None:
            return {}
        stage_vals_ovds = stage_cfg.get('values')
        if stage_vals_ovds is None:
            return {}
        return stage_vals_ovds

    def get_dependency_platform_overrides(self, platform: str):
        platform_ovds = self.flow_cfg[platform].get('dependencies')
        if platform_ovds is None:
            return {}
        return platform_ovds


class FlowConfig:
    platform: str
    r_env: ResolutionEnv
    dependencies_explicit: 'dict[str, ]'
    stages: 'dict[str, Stage]'

    def __init__(self, project_config: ProjectFlowConfig,
                 platform_def: FlowDefinition, platform: str):
        self.r_env = platform_def.r_env
        platform_vals = project_config.get_values_raw(platform)
        self.r_env.add_values(platform_vals)
        self.stages = platform_def.stages
        self.platform = platform

        raw_project_deps = project_config.get_dependencies_raw(platform)

        self.dependencies_explicit = deep(lambda p: str(Path(p).resolve()))(self.r_env.resolve(raw_project_deps))

        for stage_name, stage in platform_def.stages.items():
            project_val_ovds = \
                project_config.get_stage_value_overrides(platform, stage_name)
            stage.value_overrides.update(project_val_ovds)

    def get_dependency_overrides(self):
        return self.dependencies_explicit

    def get_r_env(self, stage_name: str) -> ResolutionEnv:
        stage = self.stages[stage_name]
        r_env = copy(self.r_env)
        r_env.add_values(stage.value_overrides)

        return r_env

    def get_stage(self, stage_name: str) -> Stage:
        return self.stages[stage_name]

class FlowConfigException(Exception):
    path: str
    message: str

    def __init__(self, path: str, message: str):
        self.path = path
        self.message = message

    def __str__(self) -> str:
        return f'Error in config `{self.path}: {self.message}'


def open_project_flow_cfg(path: str) -> ProjectFlowConfig:
    cfg = ProjectFlowConfig(path)
    with Path(path).open('r') as rfptr:
        cfg.flow_cfg = json_load(rfptr)
    return cfg
