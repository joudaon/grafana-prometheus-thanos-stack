#!/bin/bash

echo "🧹 Deleting existing clusters (if any)..."
kind delete clusters -A || true