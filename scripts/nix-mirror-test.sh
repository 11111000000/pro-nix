#!/usr/bin/env bash
# Тест скорости Nix зеркал

set -euo pipefail

MIRRORS=(
    "https://cache.nixos.org"
    "https://nix-community.cachix.org"
    "https://nix-mirror.freetls.fastly.net"
)

ITERATIONS=10
TEST_FILE="nix-cache-info"

echo "════════════════════════════════════════════════════════════"
echo " Nix Binary Cache Speed Test"
echo "════════════════════════════════════════════════════════════"
echo " Iterations: $ITERATIONS"
echo " Test file: $TEST_FILE"
echo ""

results=()

for url in "${MIRRORS[@]}"; do
    echo "────────────────────────────────────────────────────────────"
    echo " Testing: $url"
    echo "────────────────────────────────────────────────────────────"

    times=()
    for i in $(seq 1 $ITERATIONS); do
        time_taken=$(curl -s -w "%{time_total}" -o /dev/null -L "$url/$TEST_FILE" 2>/dev/null || echo "FAILED")
        if [[ "$time_taken" != "FAILED" ]]; then
            time_taken=$(echo "$time_taken" | sed 's/,/./g')
            times+=("$time_taken")
            echo "  $i/$ITERATIONS: ${time_taken}s"
        else
            printf "  %2d/%d: FAILED\n" "$i" "$ITERATIONS"
        fi
    done

    if [ ${#times[@]} -gt 0 ]; then
        # Use awk for calculations (more portable than bc)
        stats=$(echo "${times[@]}" | tr ' ' '\n' | awk '
            BEGIN { sum=0; min=999999; max=0; count=0 }
            { 
                sum+=$1; 
                if($1<min) min=$1; 
                if($1>max) max=$1; 
                count++ 
            }
            END { 
                printf "%.3f %.3f %.3f %.1f", sum/count, min, max, (count/'$ITERATIONS')*100
            }')
        avg=$(echo "$stats" | awk '{print $1}')
        min=$(echo "$stats" | awk '{print $2}')
        max=$(echo "$stats" | awk '{print $3}')
        success_rate=$(echo "$stats" | awk '{print $4}')

        echo ""
        echo "  Average: ${avg}s"
        echo "  Min: ${min}s | Max: ${max}s"
        echo "  Success rate: ${success_rate}%"

        results+=("$avg $url $success_rate")
    fi
    echo ""
done

echo "════════════════════════════════════════════════════════════"
echo " SUMMARY (sorted by speed)"
echo "════════════════════════════════════════════════════════════"

printf "%-45s %10s %8s\n" "Mirror" "Avg Time" "Success"
echo "────────────────────────────────────────────────────────────"

for line in $(echo "${results[*]}" | tr ' ' '\n' | sort -n); do
    :
done

IFS=$'\n'
sorted=($(for r in "${results[@]}"; do echo "$r"; done | sort -t' ' -k1 -n))
unset IFS

for entry in "${sorted[@]}"; do
    avg=$(echo "$entry" | cut -d' ' -f1)
    url=$(echo "$entry" | cut -d' ' -f2)
    rate=$(echo "$entry" | cut -d' ' -f3)
    printf "%-45s %7ss %6s%%\n" "$url" "$avg" "$rate"
done

echo ""
echo "Recommendation: Use mirrors in order from fastest to slowest"
