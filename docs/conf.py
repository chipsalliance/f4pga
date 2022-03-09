# -*- coding: utf-8 -*-
#
# Updated documentation of the configuration options is available at
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import sys, os
from pathlib import Path

from tabulate import tabulate

ROOT = Path(__file__).resolve().parent

#sys.path.insert(0, os.path.abspath('.'))

# -- Generate status.inc -----------------------------------------------------------------------------------------------

with (ROOT / "status.inc").open("w", encoding="utf-8") as wfptr:
    wfptr.write(
        tabulate(
            [
                ["[Basic Tiles] Logic", "Yes", "Yes", "Yes", "Yes"],
                ["[Basic Tiles] Block RAM", "Yes", "Yes", "Partial", "Yes"],
                ["[Advanced Tiles] DSP", "Yes", "Yes", "Partial", "Yes"],
                ["[Advanced Tiles] Hard Blocks", "Yes", "Yes", "Partial", "Yes"],
                ["[Advanced Tiles] Clock Tiles", "Yes", "Yes", "Yes", "Yes"],
                ["[Advanced Tiles] IO Tiles", "Yes", "Yes", "Yes", "Yes"],
                ["[Routing] Logic", "Yes", "Yes", "Yes", "Yes"],
                ["[Routing] Clock", "Yes", "Yes", "Yes", "Yes"],
            ],
            headers=["", "Project Icestorm", "Project Trellis ", "Project X-Ray", "QuickLogic Database"],
            tablefmt="rst",
        )
    )

# -- General configuration ---------------------------------------------------------------------------------------------

project = 'F4PGA'
basic_filename = 'f4pga-docs'
authors = 'F4PGA Authors'
copyright = f'{authors}, 2019 - 2022'

version = ''
release = '' # The full version, including alpha/beta/rc tags.

extensions = [
    'sphinx.ext.extlinks',
    'sphinx.ext.intersphinx',
    'sphinx_verilog_domain',
    'sphinxcontrib.bibtex',
    'myst_parser'
]

bibtex_default_style = 'plain'
bibtex_bibfiles = ['refs.bib']

numfig = True

templates_path = ['_templates']

source_suffix = {
    '.rst': 'restructuredtext',
    '.md': 'markdown'
}

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

# -- Options for HTML output -------------------------------------------------------------------------------------------

html_show_sourcelink = True

html_theme = 'sphinx_symbiflow_theme'

html_theme_options = {
    'repo_name': 'chipsalliance/f4pga',
    'github_url' : 'https://github.com/chipsalliance/f4pga',
    'globaltoc_collapse': True,
    'color_primary': 'indigo',
    'color_accent': 'blue',
}

html_static_path = ['_static']

html_logo = str(Path(html_static_path[0]) / 'logo.svg')
html_favicon = str(Path(html_static_path[0]) / 'favicon.svg')

# -- Options for LaTeX output ------------------------------------------------------------------------------------------

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

# -- Options for manual page output ------------------------------------------------------------------------------------

man_pages = [
    ('index', basic_filename, project,
     [authors], 1)
]

# -- Sphinx.Ext.InterSphinx --------------------------------------------------------------------------------------------

intersphinx_mapping = {
    "python": ("https://docs.python.org/3/", None),
    "arch-defs": ("https://f4pga.readthedocs.io/projects/arch-defs/en/latest/", None),
    "interchange": ("https://fpga-interchange-schema.readthedocs.io/", None),
    "fasm": ("https://fasm.readthedocs.io/en/latest/", None),
    "prjtrellis": ("https://prjtrellis.readthedocs.io/en/latest/", None),
    "prjxray": ("https://f4pga.readthedocs.io/projects/prjxray/en/latest/", None),
    "vtr": ("https://docs.verilogtorouting.org/en/latest/", None),
}

# -- Sphinx.Ext.ExtLinks -----------------------------------------------------------------------------------------------

extlinks = {
   'wikipedia': ('https://en.wikipedia.org/wiki/%s', 'wikipedia:'),
   'gh':        ('https://github.com/%s', 'gh:'),
   'ghsharp':   ('https://github.com/chipsalliance/f4pga/issues/%s', '#'),
   'ghissue':   ('https://github.com/chipsalliance/f4pga/issues/%s', 'issue #'),
   'ghpull':    ('https://github.com/chipsalliance/f4pga/pull/%s', 'pull request #'),
   'ghsrc':     ('https://github.com/chipsalliance/f4pga/blob/master/%s', '')
}
