""" The "ugly" module is dedicated for some *ugly* workarounds """

import os
import sf_common

def noisy_warnings():
    """ Emit some noisy warnings """
    
    os.environ['OUR_NOISY_WARNINGS'] = 'noisy_warnings.log'
    return 'noisy_warnings.log'

def generate_values():
    """ Generate initial values, available in configs """

    return{
        'prjxray_db': sf_common.sub('prjxray-config').decode().replace('\n', ''),
        'python3': sf_common.sub('which', 'python3').decode().replace('\n', ''),
        'noisyWarnings': noisy_warnings()
    }
