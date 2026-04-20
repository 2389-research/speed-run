#!/bin/bash
# Speed-run session start hook.
# Informs the user which backend is active.

if [ -z "$CEREBRAS_API_KEY" ]; then
    {
        echo "speed-run: using Haiku backend (default)."
        echo "  • Works out of the box — no setup needed."
        echo "  • For ~10x faster generation, set CEREBRAS_API_KEY."
        echo "  • Get a free Cerebras key at: https://cloud.cerebras.ai"
    } >&2
else
    {
        echo "speed-run: CEREBRAS_API_KEY detected — will use Cerebras backend for fast generation."
    } >&2
fi
