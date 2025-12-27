#!/usr/bin/env bash
# Quick patch to fix color codes in diagnose.sh and setup.sh

echo "Fixing color codes in diagnose.sh..."
sed -i "s/printf '%s=== %s ===%s\\\\n'/printf '%b=== %s ===%b\\\\n'/g" diagnose.sh
sed -i "s/printf '%s✓ %s%s\\\\n'/printf '%b✓ %s%b\\\\n'/g" diagnose.sh
sed -i "s/printf '%s✗ %s%s\\\\n'/printf '%b✗ %s%b\\\\n'/g" diagnose.sh
sed -i "s/printf '%s⚠ %s%s\\\\n'/printf '%b⚠ %s%b\\\\n'/g" diagnose.sh

echo "Fixing color codes in setup.sh..."
sed -i "s/printf '%s✓ %s%s\\\\n'/printf '%b✓ %s%b\\\\n'/g" setup.sh
sed -i "s/printf '%s✗ %s%s\\\\n'/printf '%b✗ %s%b\\\\n'/g" setup.sh
sed -i "s/printf '%s⚠ %s%s\\\\n'/printf '%b⚠ %s%b\\\\n'/g" setup.sh
sed -i "s/printf '%s→ %s%s\\\\n'/printf '%b→ %s%b\\\\n'/g" setup.sh

echo "Done! Colors should now display properly."
echo "Test with: sudo ./diagnose.sh 8.8.8.8 80"