""" The "ugly" module is dedicated for some *ugly* workarounds """

import os
from f4pga.common import sub as common_sub

def noisy_warnings():
    """ Emit some noisy warnings """

    os.environ['OUR_NOISY_WARNINGS'] = 'noisy_warnings.log'
    return 'noisy_warnings.log'

def generate_values():
    """ Generate initial values, available in configs """

    return{
        'prjxray_db': common_sub('prjxray-config').decode().replace('\n', ''),
        'python3': common_sub('which', 'python3').decode().replace('\n', ''),
        'noisyWarnings': noisy_warnings()
    }
