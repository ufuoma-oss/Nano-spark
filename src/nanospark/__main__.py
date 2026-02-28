# -*- coding: utf-8 -*-
"""Allow running NanoSpark via ``python -m nanospark``."""
from .cli.main import cli

if __name__ == "__main__":
    cli()  # pylint: disable=no-value-for-parameter
