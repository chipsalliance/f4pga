# -*- coding: utf-8 -*-
#
# Updated documentation of the configuration options is available at
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import sys, os

#sys.path.insert(0, os.path.abspath('.'))

# -- General configuration -----------------------------------------------------

project = 'F4PGA'
basic_filename = 'f4pga-docs'
authors = 'F4PGA Authors'
copyright = f'{authors}, 2019 - 2022'

version = ''
release = '' # The full version, including alpha/beta/rc tags.

extensions = [
    'sphinx.ext.intersphinx',
    'sphinx_verilog_domain'
]

numfig = True

templates_path = ['_templates']

source_suffix = ['.rst', '.md']

master_doc = 'index'

today_fmt = '%Y-%m-%d'

exclude_patterns = [
    'env'
]

pygments_style = 'default'

rst_prolog = """
.. role:: raw-latex(raw)
   :format: latex

.. role:: raw-html(raw)
   :format: html
"""

# -- Options for HTML output ---------------------------------------------------

html_show_sourcelink = True

html_theme = 'sphinx_symbiflow_theme'

html_theme_options = {
    'repo_name': 'chipsalliance/f4pga-docs',
    'github_url' : 'https://github.com/chipsalliance/f4pga-docs',
    'globaltoc_collapse': True,
    'color_primary': 'indigo',
    'color_accent': 'blue',
}

# -- Options for LaTeX output --------------------------------------------------

latex_documents = [
  ('index', basic_filename+'.tex', project,
   authors, 'manual'),
]

latex_elements = {
    'papersize': 'a4paper',
    'pointsize': '11pt',
    'fontpkg': r'''
        \usepackage{charter}
        \usepackage[defaultsans]{lato}
        \usepackage{inconsolata}
    ''',
    'preamble': r'''
          \usepackage{multicol}
    ''',
    'maketitle': r'''
        \renewcommand{\releasename}{}
        \maketitle
    ''',
    'classoptions':',openany,oneside',
    'babel': r'''
          \usepackage[english]{babel}
          \makeatletter
          \@namedef{ver@color.sty}{}
          \makeatother
          \usepackage{silence}
          \WarningFilter{Fancyhdr}{\fancyfoot's `E' option without twoside}
    '''
}

# -- Options for manual page output --------------------------------------------

man_pages = [
    ('index', basic_filename, project,
     [authors], 1)
]

# -- Sphinx.Ext.InterSphinx --------------------------------------------------------------------------------------------

intersphinx_mapping = {
    "python": ("https://docs.python.org/3/", None),
    "arch-defs": ("https://symbiflow.readthedocs.io/projects/arch-defs/en/latest/", None),
    "fasm": ("https://fasm.readthedocs.io/en/latest/", None),
    "prjtrellis": ("https://prjtrellis.readthedocs.io/en/latest/", None),
    "prjxray": ("https://symbiflow.readthedocs.io/projects/prjxray/en/latest/", None),
    "vtr": ("https://docs.verilogtorouting.org/en/latest/", None),
}
