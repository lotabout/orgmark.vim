#!/usr/bin/env python3

import os

SCRIPT_PATH = os.path.dirname(os.path.realpath(__file__))
PLACE_HOLDER_STYLE = '#style#'
PLACE_HOLDER_SCRIPT = '#script#'
PLACE_HOLDER_MARKDOWN = '#markdown#'
PLACE_HOLDER_MARKDOWN_BASE64 = '#markdown-base64#'

style_files = [
    'assets/highlight.css',
    'assets/normalize.css',
    'assets/noise.css',
    'assets/tomorrow.css',
    'assets/custom.css',
    ]
script_files = [
    'assets/highlight.min.js',
    'assets/marked.min.js',
    'assets/MathJax.js',
    'assets/custom.js',
]

template_file = os.path.join(SCRIPT_PATH, 'assets/index.html')


scripts = []
for script_file in script_files:
    if script_file.startswith('http'):
        line = f'<script src="{script_file}"></script>'
    else:
        path = script_file if script_file.startswith('/') else os.path.join(SCRIPT_PATH, script_file)
        with open(script_file) as fp:
            script_content = fp.read()
            line = f'<script>{script_content}</script>'
    scripts.append(line)

script_renderred = '\n'.join(scripts)

styles = []
for style_file in style_files:
    if style_file.startswith('http'):
        style = f'<link rel="stylesheet" href="{style_file}">'
    else:
        path = style_file if style_file.startswith('/') else os.path.join(SCRIPT_PATH, style_file)
        with open(path) as fp:
            style_content = fp.read()
            style = f'<style type="text/css" media="screen">{style_content}</style>'
    styles.append(style)

style_renderred = '\n'.join(styles)

with open(template_file) as fp:
    template_content = fp.read()

import fileinput
import sys

markdown_file = sys.argv[1]
with open(markdown_file) as fp:
    markdown = fp.read()

import base64
markdown_base64 = base64.b64encode(markdown.encode('utf8')).decode('utf8')

renderred = template_content
renderred = renderred.replace(PLACE_HOLDER_STYLE, style_renderred)
renderred = renderred.replace(PLACE_HOLDER_SCRIPT, script_renderred)
renderred = renderred.replace(PLACE_HOLDER_MARKDOWN, markdown)
renderred = renderred.replace(PLACE_HOLDER_MARKDOWN_BASE64, markdown_base64)

print(renderred)
