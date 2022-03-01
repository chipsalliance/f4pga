import os
import json

from f4pga.common import file_noext, ResolutionEnv, deep
from f4pga.stage import Stage
from copy import copy

_realpath_deep = deep(os.path.realpath)

def open_flow_cfg(path: str) -> dict:
    flow_cfg_json: str
    with open(path, 'r') as flow_cfg_file:
        flow_cfg_json = flow_cfg_file.read()
    return json.loads(flow_cfg_json)

def save_flow_cfg(flow: dict, path: str):
    flow_cfg_json = json.dumps(flow, indent=4)
    with open(path, 'w') as flow_cfg_file:
        flow_cfg_file.write(flow_cfg_json)

def _get_lazy_dict(parent: dict, name: str):
    d = parent.get(name)
    if d is None:
        d = {}
        parent[name] = d
    return d

def _get_ov_dict(dname: str, flow: dict,
                 platform: 'str | None' = None, stage: 'str | None' = None):
    d: dict
    if platform:
        platform_dict: dict = flow[platform]
        if stage:
            stage_dict: dict = _get_lazy_dict(platform_dict, stage)
            d = _get_lazy_dict(stage_dict, dname)
        else:
            d = _get_lazy_dict(platform_dict, dname)
    else:
        d = _get_lazy_dict(flow, dname)

    return d

def _get_dep_dict(flow: dict,
                  platform: 'str | None' = None, stage: 'str | None' = None):
    return _get_ov_dict('dependencies', flow, platform, stage)

def _get_vals_dict(flow: dict,
                   platform: 'str | None' = None, stage: 'str | None' = None):
    return _get_ov_dict('values', flow, platform, stage)

def _add_ov(ov_dict_getter, failstr_constr, flow_cfg: dict, name: str,
            values: list, platform: 'str | None' = None,
            stage: 'str | None' = None) -> bool:
        d = ov_dict_getter(flow_cfg, platform, stage)

        deps = d.get(name)
        if type(deps) is list:
            deps += values
        elif deps is None:
            d[name] = values
        else:
            print(failstr_constr(name))
            return False

        return True

def _rm_ov_by_values(ov_dict_getter, notset_str_constr, notlist_str_constr,
                     flow: dict, name: str, vals: list,
                     platform: 'str | None' = None,
                     stage: 'str | None' = None) -> bool:
    values_to_remove = set(vals)
    d = ov_dict_getter(flow, platform, stage)

    vallist: list = d.get(name)
    if type(vallist) is list:
        d[name] = [val for val in vallist if val not in values_to_remove]
    elif type(vallist) is None:
        print(notset_str_constr(name))
        return False
    else:
        print(notlist_str_constr(name))
        return False

    return True


def _rm_ov_by_idx(ov_dict_getter, notset_str_constr, notlist_str_constr,
                  flow: dict, name: str, idcs: list,
                  platform: 'str | None' = None,
                  stage: 'str | None' = None) -> bool:
    idcs.sort(reverse=True)

    if len(idcs) == 0:
        print(f'Index list is emtpy!')
        return False

    d = ov_dict_getter(flow, platform, stage)
    vallist: list = d.get(name)
    if type(vallist) is list:
        if idcs[0] >= len(vallist) or idcs[len(idcs) - 1] < 0:
            print(f'Index out of range (max: {len(vallist)}!')
            return False

        for idx in idcs:
            vallist.pop(idx)
    elif vallist is None:
        print(notset_str_constr(name))
        return False
    else:
        print(notlist_str_constr(name))
        return False

    return True

def _get_ovs_raw(dict_name: str, flow_cfg,
                 platform: 'str | None', stage: 'str | None'):
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

def _remove_dependencies_by_values(flow: dict, name: str, deps: list,
                                   platform: 'str | None' = None,
                                   stage: 'str | None' = None) -> bool:
    def notset_str_constr(dname):
        return f'Dependency `{dname}` is not set. Nothing to remove.'
    def notlist_str_constr(dname):
        return f'Dependency `{dname}` is not a list! Use unsetd instead.'
    return _rm_ov_by_values(_get_dep_dict, notset_str_constr, notlist_str_constr,
                            flow, name, deps, platform, stage)

def _remove_dependencies_by_idx(flow: dict, name: str, idcs: list,
                                platform: 'str | None' = None,
                                stage: 'str | None' = None) -> bool:
    def notset_str_constr(dname):
        return f'Dependency `{dname}` is not set. Nothing to remove.'
    def notlist_str_constr(dname):
        return f'Dependency `{dname}` is not a list! Use unsetd instead.'
    return _rm_ov_by_idx(_get_dep_dict, notset_str_constr, notlist_str_constr,
                         flow, name, idcs, platform, stage)

def _remove_values_by_values(flow: dict, name: str, deps: list,
                             platform: 'str | None' = None,
                             stage: 'str | None' = None) -> bool:
    def notset_str_constr(vname):
        return f'Value `{vname}` is not set. Nothing to remove.'
    def notlist_str_constr(vname):
        return f'Value `{vname}` is not a list! Use unsetv instead.'
    return _rm_ov_by_values(_get_vals_dict, notset_str_constr, notlist_str_constr,
                            flow, name, deps, platform, stage)

def _remove_values_by_idx(flow: dict, name: str, idcs: list,
                          platform: 'str | None' = None,
                          stage: 'str | None' = None) -> bool:
    def notset_str_constr(dname):
        return f'Dependency `{dname}` is not set. Nothing to remove.'
    def notlist_str_constr(dname):
        return f'Dependency `{dname}` is not a list! Use unsetv instead.'
    return _rm_ov_by_idx(_get_vals_dict, notset_str_constr, notlist_str_constr,
                         flow, name, idcs, platform, stage)

def unset_dependency(flow: dict, name: str,
                   platform: 'str | None', stage: 'str | None'):
    d = _get_dep_dict(flow, platform, stage)
    if d.get(name) is None:
        print(f'Dependency `{name}` is not set!')
        return False
    d.pop(name)
    return True

def verify_platform_name(platform: str, mypath: str):
    for plat_def_filename in os.listdir(os.path.join(mypath, 'platforms')):
        platform_name = file_noext(plat_def_filename)
        if platform == platform_name:
            return True
    return False

def verify_stage(platform: str, stage: str, mypath: str):
    # TODO: Verify stage
    return True

def _is_kword(w: str):
    return \
        (w == 'dependencies') | (w == 'values') | \
        (w == 'default_platform') | (w == 'default_target')

class FlowDefinition:
    # stage name -> module path mapping
    stages: 'dict[str, Stage]'
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
    # r_env: ResolutionEnv
    path: str
    # platform_r_envs: 'dict[str, ResolutionEnv]'

    def __init__(self, path: str):
        self.flow_cfg = {}
        self.path = copy(path)
        # self.r_env = ResolutionEnv({})
        # self.platform_r_envs = {}

    def platforms(self):
        for platform, _ in self.flow_cfg.items():
            if not _is_kword(platform):
                yield platform

    def add_platform(self, device: str) -> bool:
        d = self.flow_cfg.get(device)
        if d:
            print(f'Device {device} already exists')
            return False

        self.flow_cfg[device] = {}
        return True

    def set_default_platform(self, device: str) -> bool:
        self.flow_cfg['default_platform'] = device
        return True

    def set_default_target(self, platform: str, target: str) -> bool:
        self.flow_cfg[platform]['default_target'] = target
        return True

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

    """ Get dependencies without value resolution applied """
    def get_dependencies_raw(self, platform: 'str | None' = None):
        return _get_ovs_raw('dependencies', self.flow_cfg, platform, None)

    """ Get values without value resolution applied """
    def get_values_raw(self, platform: 'str | None' = None,
                       stage: 'str | None' = None):
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

        self.dependencies_explicit = \
            _realpath_deep(self.r_env.resolve(raw_project_deps))

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

    flow_cfg_json: str
    with open(path, 'r') as flow_cfg_file:
        flow_cfg_json = flow_cfg_file.read()
    cfg.flow_cfg = json.loads(flow_cfg_json)

    return cfg