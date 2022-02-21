# -*- coding: utf-8 -*-
#
# Updated documentation of the configuration options is available at
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import sys, os

#sys.path.insert(0, os.path.abspath('.'))

# -- General configuration -----------------------------------------------------

project = u'SymbiFlow'
basic_filename = u'symbiflow-docs'
authors = u'SymbiFlow'
copyright = authors + u', 2019'

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

html_theme = "sphinx_symbiflow_theme"

html_theme_options = {
    # Specify a list of menu in Header.
    # Tuples forms:
    #  ('Name', 'external url or path of pages in the document', boolean, 'icon name')
    #
    # Third argument:
    # True indicates an external link.
    # False indicates path of pages in the document.
    #
    # Fourth argument:
    # Specify the icon name.
    # For details see link.
    # https://material.io/icons/
    'header_links' : [
        ('Home', 'index', False, 'home'),
        ("Website", "https://symbiflow.github.io", True, 'launch'),
        ("GitHub", "https://github.com/SymbiFlow", True, 'code')
    ],

    # Customize css colors.
    # For details see link.
    # https://getmdl.io/customize/index.html
    #
    # Values: amber, blue, brown, cyan deep_orange, deep_purple, green, grey, indigo, light_blue,
    #         light_green, lime, orange, pink, purple, red, teal, yellow(Default: indigo)
    'primary_color': 'deep_purple',
    # Values: Same as primary_color. (Default: pink)
    'accent_color': 'purple',

    # Customize layout.
    # For details see link.
    # https://getmdl.io/components/index.html#layout-section
    'fixed_drawer': True,
    'fixed_header': True,
    'header_waterfall': True,
    'header_scroll': False,

    # Render title in header.
    # Values: True, False (Default: False)
    'show_header_title': False,
    # Render title in drawer.
    # Values: True, False (Default: True)
    'show_drawer_title': True,
    # Render footer.
    # Values: True, False (Default: True)
    'show_footer': True
}

html_title = project

html_last_updated_fmt = today_fmt

html_show_sphinx = False

htmlhelp_basename = basic_filename

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
