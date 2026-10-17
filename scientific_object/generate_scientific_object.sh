#!/bin/bash
set -e

# Generate the scientific object PDF
# Ensure TeX Live is in PATH if installed to /opt/texlive/2026/bin/x86_64-linux
export PATH=/usr/local/bin:/opt/texlive/2026/bin/x86_64-linux:$PATH

echo "Compiling structured scientific object..."
pdflatex -interaction=nonstopmode main.tex
pdflatex -interaction=nonstopmode main.tex

echo "Scientific object generated successfully: main.pdf"
