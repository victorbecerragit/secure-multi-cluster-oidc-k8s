#!/bin/bash
# destroy-kind.sh: Teardown local kind clusters

echo "=== Destroying kind-manager ==="
kind delete cluster --name manager

echo "=== Destroying kind-workload ==="
kind delete cluster --name workload

echo "Teardown complete."
